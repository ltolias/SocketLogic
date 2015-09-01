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

#ifndef LIBSIGROK_HARDWARE_SOCKET_LOGIC_PROTOCOL_H
#define LIBSIGROK_HARDWARE_SOCKET_LOGIC_PROTOCOL_H

#include <stdint.h>
#include <string.h>
#include <string.h>
#include <glib.h>
#include "libsigrok.h"
#include "libsigrok-internal.h"

#define LOG_PREFIX "socket-logic"



/*
 * This file is part of the libsigrok project.
 *
 * Copyright (C) 2013 Martin Ling <martin-sigrok@earth.li>
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

#ifdef _WIN32
#define _WIN32_WINNT 0x0501
#include <winsock2.h>
#include <ws2tcpip.h>
#endif
#include <glib.h>
#include <string.h>
#include <unistd.h>
#ifndef _WIN32
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#endif
#include <errno.h>
#include "libsigrok.h"
#include "libsigrok-internal.h"

#define LENGTH_BYTES 4

struct scpi_tcp {
	char *address;
	char *port;
	int socket;
	char length_buf[LENGTH_BYTES];
	int length_bytes_read;
	int response_length;
	int response_bytes_read;
};



#define RESPONSE_DELAY_US 1000000

#define NUM_CHANNELS               16
#define NUM_TRIGGER_STAGES         8
#define SERIAL_SPEED               B115200
#define CLOCK_RATE                 SR_MHZ(100)
#define MIN_NUM_SAMPLES            4
#define DEFAULT_SAMPLERATE         SR_KHZ(200)

/* Command opcodes */
#define CMD_RESET                  0x00
#define CMD_RUN                    0x01
#define CMD_TESTMODE               0x03
#define CMD_ID                     0x02
#define CMD_METADATA               0x04
#define CMD_SET_FLAGS              0x82
#define CMD_SET_DIVIDER            0x80
#define CMD_CAPTURE_SIZE           0x81
#define CMD_SET_TRIGGER_MASK       0xc0
#define CMD_SET_TRIGGER_VALUE      0xc1
#define CMD_SET_TRIGGER_CONFIG     0xc2

/* Trigger config */
#define TRIGGER_START              (1 << 3)

/* Bitmasks for CMD_FLAGS */
/* 12-13 unused, 14-15 RLE mode (we hardcode mode 0). */
#define FLAG_INTERNAL_TEST_MODE    (1 << 11)
#define FLAG_EXTERNAL_TEST_MODE    (1 << 10)
#define FLAG_SWAP_CHANNELS         (1 << 9)
#define FLAG_RLE                   (1 << 8)
#define FLAG_SLOPE_FALLING         (1 << 7)
#define FLAG_CLOCK_EXTERNAL        (1 << 6)
#define FLAG_CHANNELGROUP_4        (1 << 5)
#define FLAG_CHANNELGROUP_3        (1 << 4)
#define FLAG_CHANNELGROUP_2        (1 << 3)
#define FLAG_CHANNELGROUP_1        (1 << 2)
#define FLAG_FILTER                (1 << 1)
#define FLAG_DEMUX                 (1 << 0)

#define LEVEL_RISING 2
#define LEVEL_FALLING 3
#define LEVEL_LOW 0
#define LEVEL_HIGH 1

/* Private, per-device-instance driver context. */
struct dev_context {
	/* Fixed device settings */
	int max_channels;
	uint32_t max_samples;
	uint32_t max_samplerate;
	uint32_t protocol_version;

	/* Acquisition settings */
	uint64_t cur_samplerate;
	uint32_t cur_samplerate_divider;
	uint64_t limit_samples;
	uint64_t limit_frames;
	uint64_t capture_ratio;
	int trigger_at;
	uint32_t channel_mask;
	uint16_t trigger_mask[NUM_TRIGGER_STAGES];
	uint16_t trigger_value[NUM_TRIGGER_STAGES];
	int num_stages;
	uint16_t flag_reg;
	uint16_t device_mode;
	uint64_t timebase;
	uint64_t buffersize;
	uint16_t trigger_source;
	uint16_t trigger_slope;
	int32_t num_vdiv;
	uint16_t coupling;
	int32_t num_logic_channels;
	GSList *enabled_channels;

	/* Operational states */
	unsigned int num_transfers;
	unsigned int num_samples;
	unsigned int num_frames;
	int num_bytes;
	int cnt_bytes;
	int cnt_samples;
	int cnt_samples_rle;

	/* Temporary variables */
	unsigned int rle_count;
	unsigned char sample[2];
	unsigned char tmp_sample[2];
	unsigned char *raw_sample_buf;
	int stopped;
};


SR_PRIV extern const char *socketlogic_channel_names[];

SR_PRIV int socketlogic_send_shortcommand(struct scpi_tcp *tcp,
		uint8_t command);
SR_PRIV int socketlogic_send_longcommand(struct scpi_tcp *tcp,
		uint8_t command, uint8_t *data);
SR_PRIV void socketlogic_channel_mask(const struct sr_dev_inst *sdi);
SR_PRIV int socketlogic_convert_trigger(const struct sr_dev_inst *sdi);
SR_PRIV struct dev_context *socketlogic_dev_new(void);
SR_PRIV int socketlogic_set_samplerate(const struct sr_dev_inst *sdi,
		uint64_t samplerate);
SR_PRIV void socketlogic_abort_acquisition(const struct sr_dev_inst *sdi);
SR_PRIV void socketlogic_stop(const struct sr_dev_inst *sdi);
SR_PRIV int socketlogic_receive_data(int fd, int revents, void *cb_data);



SR_PRIV int scpi_tcp_dev_inst_new(void *priv, struct drv_context *drvc,
		const char *resource, char **params, const char *serialcomm);

SR_PRIV int scpi_tcp_open(void *priv);

SR_PRIV int scpi_tcp_source_add(struct sr_session *session, void *priv,
		int events, int timeout, sr_receive_data_callback cb, void *cb_data);


SR_PRIV int scpi_tcp_source_remove(struct sr_session *session, void *priv);

SR_PRIV int scpi_tcp_send(void *priv, const char *command);


SR_PRIV int scpi_tcp_read_begin(void *priv);

SR_PRIV int scpi_tcp_raw_read_data(void *priv, char *buf, int maxlen);

SR_PRIV int scpi_tcp_rigol_read_data(void *priv, char *buf, int maxlen);
SR_PRIV int scpi_tcp_read_complete(void *priv);
SR_PRIV int scpi_tcp_close(void *priv);

SR_PRIV void scpi_tcp_free(void *priv);

#endif
