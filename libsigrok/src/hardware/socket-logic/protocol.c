/*
 * This file is part of the libsigrok project.
 *
 * Copyright (C) 2013 Bert Vermeulen <bert@biot.com>
 * this file: Leonidas Tolias <ltol
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


#include "protocol.h"

extern SR_PRIV struct sr_dev_driver socket_logic_driver_info;


SR_PRIV void socket_logic_channel_mask(const struct sr_dev_inst *sdi)
{
	struct dev_context *devc;
	struct sr_channel *channel;
	const GSList *l;

	devc = sdi->priv;

	if (devc->analog_channels)
	{
		g_slist_free(devc->analog_channels);
		devc->analog_channels = NULL;
	}
	if (devc->logic_channels)
	{
		g_slist_free(devc->logic_channels);
		devc->logic_channels = NULL;
	}
	for (l = sdi->channels; l; l = l->next) {
		channel = l->data;
		if (channel->enabled)
		{
			if (channel->type == SR_CHANNEL_ANALOG)
				devc->analog_channels = g_slist_append(devc->analog_channels, channel);
			else
				devc->logic_channels = g_slist_append(devc->logic_channels, channel);

		}
	}
}

SR_PRIV int socket_logic_send_shortcommand(struct tcp_socket *tcp,
		uint8_t command)
{
	char *terminated_command;

	terminated_command = g_strdup_printf("%.2x", command);
	
	sr_dbg("Sending cmd 0x%.2x.", command);
	if (tcp_socket_send(tcp, terminated_command) <= 0)
	{
		g_free(terminated_command);
		return SR_ERR;
	}
	g_free(terminated_command);
	return SR_OK;
}

SR_PRIV int socket_logic_send_longcommand(struct tcp_socket *tcp,
		uint8_t command, uint8_t *data)
{
	char *terminated_command;

	terminated_command = g_strdup_printf("%.2x%.2x%.2x%.2x%.2x", command, data[0], data[1], data[2], data[3]);
	
	sr_dbg("Sending cmd 0x%.2x data 0x%.2x%.2x%.2x%.2x.", command,
			data[0], data[1], data[2], data[3]);

	if (tcp_socket_send(tcp, terminated_command) <= 0)
	{
		g_free(terminated_command);
		return SR_ERR;
	}
	g_free(terminated_command);
	return SR_OK;
}


SR_PRIV int tcp_socket_open(void *priv)
{
	struct tcp_socket *tcp = priv;
	struct addrinfo hints;
	struct addrinfo *results, *res;
	int err;

	memset(&hints, 0, sizeof(hints));
	hints.ai_family = AF_INET;
	hints.ai_socktype = SOCK_STREAM;
	hints.ai_protocol = IPPROTO_TCP;

	err = getaddrinfo(tcp->address, tcp->port, &hints, &results);

	if (err) {
		sr_err("Address lookup failed: %s:%d: %s", tcp->address, tcp->port,
			gai_strerror(err));
		return SR_ERR;
	}

	for (res = results; res; res = res->ai_next) {
		if ((tcp->socket = socket(hints.ai_family, hints.ai_socktype,
						hints.ai_protocol)) < 0)
			continue;
		if (connect(tcp->socket, res->ai_addr, res->ai_addrlen) != 0) {
			close(tcp->socket);
			tcp->socket = -1;
			continue;
		}
		break;
	}

	freeaddrinfo(results);

	if (tcp->socket < 0) {
		sr_err("Failed to connect to %s:%s: %s", tcp->address, tcp->port,
				strerror(errno));
		return SR_ERR;
	}

	return SR_OK;
}


SR_PRIV int tcp_socket_source_add(struct sr_session *session, void *priv,
		int events, int timeout, sr_receive_data_callback cb, void *cb_data)
{
	struct tcp_socket *tcp = priv;

	return sr_session_source_add(session, tcp->socket, events, timeout,
			cb, cb_data);
}

SR_PRIV int tcp_socket_source_remove(struct sr_session *session, void *priv)
{
	struct tcp_socket *tcp = priv;

	return sr_session_source_remove(session, tcp->socket);
}

SR_PRIV int tcp_socket_send(void *priv, const char *command)
{
	struct tcp_socket *tcp = priv;
	int len, out;
	char *terminated_command;



	terminated_command = g_strdup_printf("%s\n", command);
	len = strlen(terminated_command);
	out = send(tcp->socket, terminated_command, len, 0);
	g_free(terminated_command);

	if (out < 0) {
		sr_err("Send error: %s", strerror(errno));
		return SR_ERR;
	}

	if (out < len) {
		sr_dbg("Only sent %d/%d bytes of tcp command: '%s'.", out,
		       len, command);
	}

	sr_spew("Successfully sent tcp command: '%s'.", command);
	
	return out;
}

SR_PRIV int tcp_socket_raw_read_data(void *priv, unsigned char *buf, int maxlen)
{
	struct tcp_socket *tcp = priv;
	int len;

	len = recv(tcp->socket, buf, maxlen, 0);

	if (len < 0) {
		sr_err("Receive error: %s", strerror(errno));
		return SR_ERR;
	}

	tcp->length_bytes_read = LENGTH_BYTES;
	tcp->response_length = len < maxlen ? len : maxlen + 1;
	tcp->response_bytes_read = len;

	return len;
}


SR_PRIV int tcp_socket_close(void *priv)
{
	struct tcp_socket *tcp = priv;

	if (close(tcp->socket) < 0)
		return SR_ERR;

	return SR_OK;
}

SR_PRIV void tcp_socket_free(void *priv)
{
	struct tcp_socket *tcp = priv;

	g_free(tcp->address);
	g_free(tcp->port);
}

SR_PRIV struct dev_context *socket_logic_dev_new(void)
{
	struct dev_context *devc;

	if (!(devc = g_try_malloc(sizeof(struct dev_context)))) {
		sr_err("Device context malloc failed.");
		return NULL;
	}

	/* Device-specific settings */
	devc->max_samples = 100000000;
	devc->max_samplerate = 100000000;
	devc->protocol_version = 0;

	/* Acquisition settings */
	devc->limit_samples = 100;
	devc->limit_frames = 100;
	devc->cur_samplerate = 10000;
	devc->capture_ratio = 100;
	devc->flag_reg = 0;
	devc->analog_channels = NULL;
	devc->logic_channels = NULL;
	devc->last_limit_samples1 = 1000000000000;
	devc->last_limit_samples0 = 0;;

	devc->device_mode = 0;
	devc->timebase = 0;
	devc->buffersize = 0;
	devc->trigger_source = 0;
	devc->trigger_slope = 0;
	devc->num_vdiv = 0;
	devc->coupling = 0;
	devc->stopped = 0;


	return devc;
}


SR_PRIV void socket_logic_abort_acquisition(const struct sr_dev_inst *sdi)
{
	struct dev_context *devc;
	devc = sdi->priv;
	devc->stopped = 1;
}


SR_PRIV void socket_logic_stop(const struct sr_dev_inst *sdi)
{
	struct sr_datafeed_packet packet;
	struct tcp_socket *tcp;

	tcp = sdi->conn;
	tcp_socket_source_remove(sdi->session, tcp);

	/* Terminate session */
	packet.type = SR_DF_END;
	sr_session_send(sdi, &packet);
}

SR_PRIV int socket_logic_receive_data(int fd, int revents, void *cb_data)
{
	struct dev_context *devc;
	struct sr_dev_inst *sdi;
	struct tcp_socket *tcp;
	struct sr_datafeed_packet packet;
	struct sr_datafeed_packet packet2;
	struct sr_datafeed_logic logic;
	uint16_t sample;
	int num_socket_logic_changrp, offset;
	unsigned int i, j;
	unsigned char byte;

	(void)fd;

	uint64_t limit_frames  = 1;

	sdi = cb_data;
	tcp = sdi->conn;
	devc = sdi->priv;
	if (devc->device_mode != 0)
		limit_frames = devc->limit_frames;
	
	if (devc->num_transfers++ == 0) 
	{
		//first time around
		tcp_socket_source_remove(sdi->session, tcp);

		tcp_socket_source_add(sdi->session, tcp, G_IO_IN, 1000,
				socket_logic_receive_data, cb_data);


		devc->raw_sample_buf = g_try_malloc(devc->limit_samples * 2);
		if (!devc->raw_sample_buf) {
			sr_err("Sample buffer malloc failed.");
			return FALSE;
		}
		/* fill with 1010... for debugging */
		memset(devc->raw_sample_buf, 0x82, devc->limit_samples * 2);
	}

	if (revents == G_IO_IN && devc->num_samples < devc->limit_samples && devc->num_frames < limit_frames) 
	{
		if (tcp_socket_raw_read_data(tcp, &byte, 1) != 1)
			return FALSE;
		devc->cnt_bytes++;

		if (devc->num_samples == 0 && devc->num_bytes == 0)
		{
			struct sr_datafeed_packet packet3;
			packet3.type = SR_DF_FRAME_BEGIN;
			sr_session_send(cb_data, &packet3);
		}

		// Ignore it if we've read enough.
		if (devc->num_samples >= devc->limit_samples)
			return TRUE;

		devc->sample[devc->num_bytes++] = byte;
		sr_spew("Received byte 0x%.2x.", byte);

		if (devc->num_bytes == 2) {
			devc->cnt_samples++;
			//got full sample
			sample = devc->sample[0] | (devc->sample[1] << 8);
			sr_dbg("Received sample 0x%.*x.", devc->num_bytes * 2, sample);
			
			
			if (devc->num_samples > devc->limit_samples) {
				// Save us from overrunning the buffer.
				devc->num_samples = devc->limit_samples;
			}
			offset = devc->num_samples * 2;
			devc->num_samples ++;
		
			memcpy(devc->raw_sample_buf + offset, devc->sample, 2);
		
			memset(devc->sample, 0, 2);
			devc->num_bytes = 0;
		}
	} else if (devc->num_frames < limit_frames){
		//finished getting samples
		sr_dbg("Received %d bytes, %d samples.",
				devc->cnt_bytes, devc->cnt_samples);
	
		// Send the trigger. (should really send pre trigger samples first but eh...)
		packet.type = SR_DF_TRIGGER;
		sr_session_send(cb_data, &packet);

		//send logic samples
		int num_logic_ch = g_slist_length(devc->logic_channels);
		if (num_logic_ch > 0)
		{
			
			packet.type = SR_DF_LOGIC;
			packet.payload = &logic;
			logic.length = (devc->num_samples * 2);
			logic.unitsize = 2;
			logic.data = devc->raw_sample_buf;
			sr_session_send(cb_data, &packet);
		}
		//send analog samples
		int num_analog_ch = g_slist_length(devc->analog_channels);
		if (num_analog_ch > 0)
		{
			struct sr_datafeed_analog analog;
			analog.channels = devc->analog_channels;
			analog.num_samples = devc->num_samples*num_analog_ch;

			analog.data = g_try_malloc(devc->num_samples * sizeof(float) * num_analog_ch);
			int data_offset = 0;
			for (j = 0; j < devc->num_samples; j++) {
				if (num_analog_ch >= 1) {
					float ch1 = (float)*(devc->raw_sample_buf + j * 2);
					analog.data[data_offset++] = ch1;
				}
				if (num_analog_ch == 2) {
					float ch2 = (float)*(devc->raw_sample_buf + j * 2 + 1);
					analog.data[data_offset++] = ch2;
				}
			}
			analog.mq = SR_MQ_VOLTAGE;
			analog.unit = SR_UNIT_VOLT;
			analog.mqflags = 0;
			packet.type = SR_DF_ANALOG;
			packet.payload = &analog;
			sr_session_send(cb_data, &packet);
		}	

		// Reset operational states

		devc->num_samples = devc->num_bytes = 0;
		devc->cnt_bytes = devc->cnt_samples = 0;
		memset(devc->sample, 0, 2);
		devc->num_frames++;

		//are we ending?
		if (devc->stopped == 1)
			devc->num_frames = limit_frames;
		//incase we're in oscilloscope mode
		if (devc->num_frames < limit_frames)
		{
			packet2.type = SR_DF_FRAME_END;
			sr_session_send(cb_data, &packet2);

			if (socket_logic_send_shortcommand(tcp, CMD_WAIT_TRIGGER) != SR_OK)
				return SR_ERR;	
		}
	}
	else
	{	
		g_free(devc->raw_sample_buf);
		socket_logic_stop(sdi);
	}
	

	return TRUE;
}
