/*
 * This file is part of the libsigrok project.
 *
 * Copyright (C) 2013 Bert Vermeulen <bert@biot.com>
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
#include <libserialport.h>
#include <stdio.h>
#include <string.h>

#define SERIALCOMM "127.0.0.1:8080"

static const uint32_t scanopts[] = {
	SR_CONF_CONN,
	SR_CONF_SERIALCOMM,
};


static const uint32_t drvopts[] = {
	SR_CONF_LOGIC_ANALYZER,
	SR_CONF_OSCILLOSCOPE,
};


static const uint32_t devopts[] = {
	SR_CONF_LOGIC_ANALYZER,
	SR_CONF_OSCILLOSCOPE,
	SR_CONF_DEVICE_MODE | SR_CONF_GET | SR_CONF_SET | SR_CONF_LIST,
	SR_CONF_LIMIT_FRAMES | SR_CONF_GET | SR_CONF_SET | SR_CONF_LIST,
	SR_CONF_LIMIT_SAMPLES | SR_CONF_GET | SR_CONF_SET | SR_CONF_LIST,
	SR_CONF_SAMPLERATE | SR_CONF_GET | SR_CONF_SET | SR_CONF_LIST,
	SR_CONF_CAPTURE_RATIO | SR_CONF_GET | SR_CONF_SET,
	//SR_CONF_NUM_TIMEBASE, | SR_CONF_GET | SR_CONF_SET,

	//SR_CONF_TIMEBASE | SR_CONF_GET | SR_CONF_SET | SR_CONF_LIST,
	SR_CONF_BUFFERSIZE | SR_CONF_GET | SR_CONF_SET | SR_CONF_LIST,
	SR_CONF_TRIGGER_SOURCE | SR_CONF_GET | SR_CONF_SET | SR_CONF_LIST,
	SR_CONF_TRIGGER_SLOPE | SR_CONF_GET | SR_CONF_SET | SR_CONF_LIST,
	SR_CONF_NUM_VDIV | SR_CONF_GET | SR_CONF_SET | SR_CONF_LIST,
	SR_CONF_COUPLING | SR_CONF_GET | SR_CONF_SET | SR_CONF_LIST,
};

static const char *tsourceopts[] = {
	"CH1",
	"CH2",
	"EXT",
	/* TODO: forced */
};

static const char *tslopeopts[] = {
	"r",
	"f",
};

static const char *devmodeopts[] = {
	"Single",
	"Continuous",
};

static const char *coupleopts[] = {
	"AC",
	"DC",
	"GND",
};



/* Channels are numbered 0-31 (on the PCB silkscreen). */
SR_PRIV const char *socket_logic_channel_names[NUM_CHANNELS+1] = {
	"d0", "d1", "d2", "d3", "d4", "d5", "d6", "d7", "d8", "d9", "d10", "d11", "d12",
	"d13", "d14", "d15","a0", "a1",NULL,
};

/* Default supported samplerates, can be overridden by device metadata. */
static const uint64_t samplerates[] = {
	SR_HZ(10),
	SR_MHZ(200),
	SR_HZ(1),
};

SR_PRIV struct sr_dev_driver socket_logic_driver_info;
static struct sr_dev_driver *di = &socket_logic_driver_info;

static int init(struct sr_context *sr_ctx)
{
	return std_init(sr_ctx, di, LOG_PREFIX);
}

static GSList *scan(GSList *options)
{
	struct sr_config *src;
	struct sr_dev_inst *sdi;
	struct drv_context *drvc;
	struct dev_context *devc;
	struct sr_channel *ch;
	struct scpi_tcp *tcp;
	struct sr_channel_group *lcg0, *lcg1, *acg;
	GSList *l, *devices;
	int ret, i;
	const char *conn, *serialcomm;
	unsigned char buf[8];

	drvc = di->priv;

	devices = NULL;

	conn = serialcomm = NULL;
	for (l = options; l; l = l->next) {
		src = l->data;
		switch (src->key) {
		case SR_CONF_CONN:
			conn = g_variant_get_string(src->data, NULL);
			break;
		case SR_CONF_SERIALCOMM:
			serialcomm = g_variant_get_string(src->data, NULL);
			break;
		}
	}
	if (!conn)
		return NULL;



	//if (serialcomm == NULL)
	

	/*if (!(serial = sr_serial_dev_inst_new(conn, serialcomm)))
		return NULL;*/

	if (!(tcp = g_try_malloc(sizeof(struct scpi_tcp)))) {
            sr_err("hwdriver: %s: tcp malloc failed", __func__);
          return NULL;
	}
	//printf("conn: %s\n",conn);
	int len = strlen(conn);
	char to[17] = "ff";
    strncpy(to, conn, len-5);
    to[len-5] = '\0';
	tcp->address = g_strdup(to);
	strncpy(to, conn+len-4, 4);
	to[4] = '\0';
	tcp->port    = g_strdup(to);
	tcp->socket  = -1;

	/* The discovery procedure is like this: first send the Reset
	 * command (0x00) 5 times, since the device could be anywhere
	 * in a 5-byte command. Then send the ID command (0x02).
	 * If the device responds with 4 bytes ("socket_logic1" or "SLA1"), we
	 * have a match.
	 */
	sr_info("Probing %s.", serialcomm);
	if (scpi_tcp_open(tcp) != SR_OK)
		return NULL;
	
	ret = SR_OK;
	for (i = 0; i < 5; i++) {
		if ((ret = socket_logic_send_shortcommand(tcp, CMD_RESET)) != SR_OK) {
			sr_err("Port %s is not writable.", serialcomm);
			break;
		}
		scpi_tcp_close(tcp);
		scpi_tcp_open(tcp);
	}
	if (ret != SR_OK) {
		scpi_tcp_close(tcp);
		sr_err("Could not use port %s. Quitting.", serialcomm);
		return NULL;
	}
	socket_logic_send_shortcommand(tcp, CMD_ID);

			
	g_usleep(RESPONSE_DELAY_US);


	ret = scpi_tcp_raw_read_data(tcp, buf, 4);
	scpi_tcp_close(tcp);
	if (ret != 4) {
		sr_err("Invalid reply (expected 4 bytes, got %d).", ret);
		return NULL;
	}

	if (strncmp(buf, "1SLO", 4) && strncmp(buf, "1ALS", 4)) {
		sr_err("Invalid reply (expected '1SLO' or '1ALS', got "
		       "'%c%c%c%c').", buf[0], buf[1], buf[2], buf[3]);
		return NULL;
	}


	/* Not an OLS -- some other board that uses the sump protocol. */
	sr_info("Device does not support metadata.");
	sdi = sr_dev_inst_new();
	sdi->status = SR_ST_INACTIVE;
	sdi->vendor = g_strdup("Tolias");
	sdi->model = g_strdup("SocketLogic");
	sdi->version = g_strdup("v0.1");
	sdi->driver = di;


	for (i = 0; socket_logic_channel_names[i] ; i++) {
			int chtype = (i == 16 || i == 17) ? SR_CHANNEL_ANALOG : SR_CHANNEL_LOGIC;
			if (!(ch = sr_channel_new(i, chtype, TRUE,
					socket_logic_channel_names[i])))
				return 0;
			sdi->channels = g_slist_append(sdi->channels, ch);
	}

	devc = socket_logic_dev_new();
	sdi->priv = devc;


	/* Configure samplerate and divider. */
	if (socket_logic_set_samplerate(sdi, DEFAULT_SAMPLERATE) != SR_OK)
		sr_dbg("Failed to set default samplerate (%"PRIu64").",
				DEFAULT_SAMPLERATE);
	sdi->inst_type = SR_INST_SERIAL;
	sdi->conn = tcp;

	drvc->instances = g_slist_append(drvc->instances, sdi);
	devices = g_slist_append(devices, sdi);

	

	return devices;
}

static GSList *dev_list(void)
{
	return ((struct drv_context *)(di->priv))->instances;
}


static void clear_dev_context(void *priv)
{
	struct dev_context *devc;

	devc = priv;
	g_slist_free(devc->analog_channels);
	g_slist_free(devc->logic_channels);

}


static int dev_clear(void)
{
	return std_dev_clear(di, clear_dev_context);
}



static int cleanup(void)
{
	return dev_clear();
}

static int config_get(uint32_t key, GVariant **data, const struct sr_dev_inst *sdi,
		const struct sr_channel_group *cg)
{
	struct dev_context *devc;

	(void)cg;

	if (!sdi)
		return SR_ERR_ARG;

	devc = sdi->priv;
	switch (key) {
	case SR_CONF_SAMPLERATE:
		*data = g_variant_new_uint64(devc->cur_samplerate);
		break;
	case SR_CONF_CAPTURE_RATIO:
		*data = g_variant_new_uint64(devc->capture_ratio);
		break;
	case SR_CONF_LIMIT_SAMPLES:
		*data = g_variant_new_uint64(devc->limit_samples);
		break;
	case SR_CONF_DEVICE_MODE:
		*data = g_variant_new_string(devmodeopts[devc->device_mode]);
		break;
	case SR_CONF_LIMIT_FRAMES:
		*data = g_variant_new_uint64(devc->limit_frames);
		break;
	/*case SR_CONF_TIMEBASE:
		*data = g_variant_new_uint64(devc->timebase);
		break;*/
	case SR_CONF_BUFFERSIZE:
		*data = g_variant_new_uint64(devc->buffersize);
		break;
	case SR_CONF_TRIGGER_SOURCE:
		*data = g_variant_new_string(tsourceopts[devc->trigger_source]);
		break;
	case SR_CONF_TRIGGER_SLOPE:
		*data = g_variant_new_string(tslopeopts[devc->trigger_slope]);
		break;
	case SR_CONF_NUM_VDIV:
		*data = g_variant_new_int32(devc->num_vdiv);
		break;
	case SR_CONF_COUPLING:
		*data = g_variant_new_string(coupleopts[devc->coupling]);
		break;
	default:
		return SR_ERR_NA;
	}

	return SR_OK;
}

static int config_set(uint32_t key, GVariant *data, const struct sr_dev_inst *sdi,
		const struct sr_channel_group *cg)
{
	struct dev_context *devc;
	uint64_t tmp_u64;
	uint16_t tmp_u16;
	int32_t tmp_32;
	int ret = SR_OK;
	const char *tmp_str;
	(void)cg;
	int i;

	if (sdi->status != SR_ST_ACTIVE)
		return SR_ERR_DEV_CLOSED;

	devc = sdi->priv;

	switch (key) {
	case SR_CONF_SAMPLERATE:
		tmp_u64 = g_variant_get_uint64(data);
		if (tmp_u64 < samplerates[0] || tmp_u64 > samplerates[1])
			return SR_ERR_SAMPLERATE;
		devc->cur_samplerate = tmp_u64;
		ret = socket_logic_set_samplerate(sdi, g_variant_get_uint64(data));
		break;
	case SR_CONF_LIMIT_SAMPLES:
		tmp_u64 = g_variant_get_uint64(data);
		if (tmp_u64 < MIN_NUM_SAMPLES)
			return SR_ERR;
		devc->limit_samples = tmp_u64;
		ret = SR_OK;
		break;
	case SR_CONF_CAPTURE_RATIO:
		devc->capture_ratio = g_variant_get_uint64(data);
		if (devc->capture_ratio < 0 || devc->capture_ratio > 100) {
			devc->capture_ratio = 0;
			ret = SR_ERR;
		} else
			ret = SR_OK;
		break;
	case SR_CONF_DEVICE_MODE:
		tmp_str = g_variant_get_string(data, NULL);
		for (i = 0; devmodeopts[i]; i++) {
			if (!strcmp(tmp_str, devmodeopts[i])) {
				if (i == 1)
				{
					devc->last_limit_samples0 = devc->limit_samples;
					devc->limit_samples = devc->last_limit_samples1;
				}
				else
				{
					devc->last_limit_samples1 = devc->limit_samples;
					devc->limit_samples = devc->last_limit_samples0;
				}
				devc->device_mode = i;
				break;
			}
		}
		break;
	case SR_CONF_LIMIT_FRAMES:
		tmp_u64 = g_variant_get_uint64(data);
		devc->limit_frames = tmp_u64;
		ret = SR_OK;
		break;
	/*case SR_CONF_TIMEBASE:
		tmp_u64 = g_variant_get_uint64(data);
		devc->timebase = tmp_u64;
		ret = SR_OK;
		break;*/
	case SR_CONF_BUFFERSIZE:
		tmp_u64 = g_variant_get_uint64(data);
		devc->buffersize = tmp_u64;
		ret = SR_OK;
		break;
	case SR_CONF_TRIGGER_SOURCE:
		tmp_str = g_variant_get_string(data, NULL);
		for (i = 0; tsourceopts[i]; i++) {
			if (!strcmp(tmp_str, tsourceopts[i])) {
				devc->trigger_source = i;
				break;
			}
		}
		break;
	case SR_CONF_TRIGGER_SLOPE:
		tmp_str = g_variant_get_string(data, NULL);
		for (i = 0; tslopeopts[i]; i++) {
			if (!strcmp(tmp_str, tslopeopts[i])) {
				devc->trigger_slope = i;
				break;
			}
		}
		break;
	case SR_CONF_NUM_VDIV:
		tmp_32 = g_variant_get_int32(data);
		devc->num_vdiv = tmp_32;
		ret = SR_OK;
		break;
	case SR_CONF_COUPLING:
		tmp_str = g_variant_get_string(data, NULL);
		for (i = 0; coupleopts[i]; i++) {
			if (!strcmp(tmp_str, coupleopts[i])) {
				devc->trigger_source = i;
				break;
			}
		}
		break;

	default:
		ret = SR_ERR_NA;
	}


	return ret;
}

static int config_list(uint32_t key, GVariant **data, const struct sr_dev_inst *sdi,
		const struct sr_channel_group *cg)
{
	GVariant *gvar, *grange[2];
	GVariantBuilder gvb;
	struct dev_context *devc;

	(void)cg;

	switch (key) {
	case SR_CONF_SCAN_OPTIONS:
		*data = g_variant_new_fixed_array(G_VARIANT_TYPE_UINT32,
				scanopts, ARRAY_SIZE(scanopts), sizeof(uint32_t));
		break;
	case SR_CONF_DEVICE_OPTIONS:
		if (!sdi)
			*data = g_variant_new_fixed_array(G_VARIANT_TYPE_UINT32,
					drvopts, ARRAY_SIZE(drvopts), sizeof(uint32_t));
		else
			*data = g_variant_new_fixed_array(G_VARIANT_TYPE_UINT32,
					devopts, ARRAY_SIZE(devopts), sizeof(uint32_t));
		break;
	case SR_CONF_DEVICE_MODE:
		*data = g_variant_new_strv(devmodeopts,
					ARRAY_SIZE(devmodeopts));
		break;
	case SR_CONF_TRIGGER_SOURCE:
		*data = g_variant_new_strv(tsourceopts,
					ARRAY_SIZE(tsourceopts));
		break;
	case SR_CONF_TRIGGER_SLOPE:
		*data = g_variant_new_strv(tslopeopts,
					ARRAY_SIZE(tslopeopts));
		break;
	case SR_CONF_COUPLING:
		*data = g_variant_new_strv(coupleopts,
					ARRAY_SIZE(coupleopts));
		break;
	case SR_CONF_SAMPLERATE:
		g_variant_builder_init(&gvb, G_VARIANT_TYPE("a{sv}"));
		gvar = g_variant_new_fixed_array(G_VARIANT_TYPE("t"), samplerates,
				ARRAY_SIZE(samplerates), sizeof(uint64_t));
		g_variant_builder_add(&gvb, "{sv}", "samplerate-steps", gvar);
		*data = g_variant_builder_end(&gvb);
		break;
	case SR_CONF_LIMIT_SAMPLES:

		grange[0] = g_variant_new_uint64(100);
		grange[1] = g_variant_new_uint64(1000000);

		if (sdi->status == SR_ST_ACTIVE)
		{
			devc = sdi->priv;
			if (devc->device_mode == 1)
			{
				grange[1] = g_variant_new_uint64(1500);
			}
		}
		
	
		*data = g_variant_new_tuple(grange, 2);
		break;
	case SR_CONF_LIMIT_FRAMES:

		grange[0] = g_variant_new_uint64(-1);
		grange[1] = g_variant_new_uint64(100);

		*data = g_variant_new_tuple(grange, 2);
		break;
	case SR_CONF_CAPTURE_RATIO:

		grange[0] = g_variant_new_uint64(0);
		grange[1] = g_variant_new_uint64(100);

		*data = g_variant_new_tuple(grange, 2);
		break;
	case SR_CONF_BUFFERSIZE:

		grange[0] = g_variant_new_uint64(10);
		grange[1] = g_variant_new_uint64(1000);

		*data = g_variant_new_tuple(grange, 2);
		break;
	case SR_CONF_NUM_VDIV:

		grange[0] = g_variant_new_uint64(10);
		grange[1] = g_variant_new_uint64(100);

		*data = g_variant_new_tuple(grange, 2);
		break;
	default:
		return SR_ERR_NA;
	}

	return SR_OK;
}

static int set_trigger(const struct sr_dev_inst *sdi, int stage)
{
	struct dev_context *devc;
	struct scpi_tcp *tcp;
	uint8_t cmd, arg[4];

	devc = sdi->priv;
	tcp = sdi->conn;

	cmd = CMD_SET_TRIGGER_MASK;
	arg[0] = devc->trigger_mask[stage] & 0xff;
	arg[1] = (devc->trigger_mask[stage] >> 8) & 0xff;
	arg[2] = stage & 0xff;
	arg[3] = 0x00;
	if (socket_logic_send_longcommand(tcp, cmd, arg) != SR_OK)
		return SR_ERR;

	cmd = CMD_SET_TRIGGER_VALUE;
	arg[0] = devc->trigger_value[stage] & 0xff;
	arg[1] = (devc->trigger_value[stage] >> 8) & 0xff;
	arg[2] = stage & 0xff;
	arg[3] = 0x00;
	if (socket_logic_send_longcommand(tcp, cmd, arg) != SR_OK)
		return SR_ERR;

	cmd = CMD_SET_TRIGGER_CONFIG;
	arg[0] = 0x00;
	arg[1] = (devc->trigger_at & 0xff);
	arg[2] = stage & 0xff;
	arg[3] = 0x00;
	if (socket_logic_send_longcommand(tcp, cmd, arg) != SR_OK)
		return SR_ERR;

	return SR_OK;
}

static int dev_acquisition_start(const struct sr_dev_inst *sdi,
		void *cb_data)
{
	struct dev_context *devc;
	struct scpi_tcp *tcp;
	uint32_t samplecount, readcount, delaycount;
	uint8_t arg[4];
	int ret, i;

	if (sdi->status != SR_ST_ACTIVE)
		return SR_ERR_DEV_CLOSED;

	devc = sdi->priv;
	tcp = sdi->conn;

	socket_logic_channel_mask(sdi);

	/*num_socket_logic_changrp = 0;
	socket_logic_changrp_mask = 0;
	for (i = 0; i < 4; i++) {
		if (devc->channel_mask & (0xff << (i * 8))) {
			socket_logic_changrp_mask |= (1 << i);
			num_socket_logic_changrp++;
		}
	}*/

	/*
	 * Limit readcount to prevent reading past the end of the hardware
	 * buffer.
	 */
	samplecount = devc->limit_samples;//MIN(devc->max_samples / num_socket_logic_changrp, devc->limit_samples);
	readcount = samplecount;

	/* Rather read too many samples than too few. */

	/* Basic triggers. */
	if (socket_logic_convert_trigger(sdi) != SR_OK) {
		sr_err("Failed to configure channels.");
		return SR_ERR;
	}
	if (devc->num_stages > 0) {
		delaycount = readcount * (1 - devc->capture_ratio / 100.0);
		devc->trigger_at = (readcount - delaycount) * 2 - devc->num_stages;
		for (i = 0; i <= devc->num_stages; i++) {
			sr_dbg("Setting socket_logic stage %d trigger.", i);
			if ((ret = set_trigger(sdi, i)) != SR_OK)
				return ret;
		}
	} else {
		/* No triggers configured, force trigger on first stage. */
		sr_dbg("Forcing trigger at stage 0.");
		if ((ret = set_trigger(sdi, 0)) != SR_OK)
			return ret;
		delaycount = readcount;
	}

	/* Samplerate. */
	sr_dbg("Setting samplerate to %" PRIu64 "Hz (divider %u)",
			devc->cur_samplerate, devc->cur_samplerate_divider);
	arg[0] = devc->cur_samplerate & 0xff;
	arg[1] = (devc->cur_samplerate & 0xff00) >> 8;
	arg[2] = (devc->cur_samplerate & 0xff0000) >> 16;
	arg[3] = (devc->cur_samplerate & 0xff000000) >> 24;
	if (socket_logic_send_longcommand(tcp, CMD_SET_DIVIDER, arg) != SR_OK)
		return SR_ERR;

	/* Send sample limit and pre/post-trigger capture ratio. */
	sr_dbg("Setting sample limit %d, trigger point at %d",
			(readcount - 1) * 4, (delaycount - 1) * 4);
	arg[0] = ((readcount - 1) & 0xff);
	arg[1] = ((readcount - 1) & 0xff00) >> 8;
	arg[2] = ((readcount - 1) & 0xff0000) >> 16;
	arg[3] = ((readcount - 1) & 0xff000000) >> 24;
	if (socket_logic_send_longcommand(tcp, CMD_CAPTURE_SIZE, arg) != SR_OK)
		return SR_ERR;

	/* Flag register. */
	sr_dbg("Setting flag register");
	/*
	 * Enable/disable socketlogic channel groups in the flag register according
	 * to the channel mask. 1 means "disable channel".
	 */
	//arg[0] = devc->device_mode & 0xff;
	arg[0] = 0x00;
	arg[1] = ((readcount - 1) & 0xff00) >> 8;
	arg[2] = ((readcount - 1) & 0xff0000) >> 16;
	arg[3] = ((readcount - 1) & 0xff000000) >> 24;
	if (socket_logic_send_longcommand(tcp, CMD_SET_FLAGS, arg) != SR_OK)
		return SR_ERR;

	/* Start acquisition on the device. */
	if (socket_logic_send_shortcommand(tcp, CMD_RUN) != SR_OK)
		return SR_ERR;

	/* Reset all operational states. */
	devc->stopped = 0;
	devc->num_transfers = 0;
	devc->num_samples = devc->num_bytes = devc->num_frames = 0;
	devc->cnt_bytes = devc->cnt_samples = 0;
	memset(devc->sample, 0, 2);

	
	/* Send header packet to the session bus. */
	std_session_send_df_header(cb_data, LOG_PREFIX);


	scpi_tcp_source_add(sdi->session, tcp, G_IO_IN, -1,
				socket_logic_receive_data, cb_data);

	return SR_OK;
}

static int dev_acquisition_stop(struct sr_dev_inst *sdi, void *cb_data)
{
	(void)cb_data;

	socket_logic_abort_acquisition(sdi);

	return SR_OK;
}

static int tcp_dev_open(struct sr_dev_inst *sdi)
{
	struct scpi_tcp *tcp;

	tcp = sdi->conn;
	if (scpi_tcp_open(tcp) != SR_OK)
		return SR_ERR;

	sdi->status = SR_ST_ACTIVE;

	return SR_OK;
}


static int tcp_dev_close(struct sr_dev_inst *sdi)
{
	struct scpi_tcp *tcp;

	tcp = sdi->conn;
	if (tcp && sdi->status == SR_ST_ACTIVE) {
		scpi_tcp_close(tcp);
		sdi->status = SR_ST_INACTIVE;
	}

	return SR_OK;
}


SR_PRIV struct sr_dev_driver socket_logic_driver_info = {
	.name = "socket-logic",
	.longname = "Socket Logic",
	.api_version = 1,
	.init = init,
	.cleanup = cleanup,
	.scan = scan,
	.dev_list = dev_list,
	.dev_clear = dev_clear,
	.config_get = config_get,
	.config_set = config_set,
	.config_list = config_list,
	.dev_open = tcp_dev_open,
	.dev_close = tcp_dev_close,
	.dev_acquisition_start = dev_acquisition_start,
	.dev_acquisition_stop = dev_acquisition_stop,
	.priv = NULL,
};
