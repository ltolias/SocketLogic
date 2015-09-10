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

#ifndef LIBSIGROK_HARDWARE_OPENBENCH_LOGIC_SNIFFER_PROTOCOL_H
#define LIBSIGROK_HARDWARE_OPENBENCH_LOGIC_SNIFFER_PROTOCOL_H


#include "libsigrok.h"
#include "libsigrok-internal.h"

#include <stdint.h>
#include <string.h>
#include <glib.h>

#include <unistd.h>
#include <errno.h>

#ifdef _WIN32
#define _WIN32_WINNT 0x0501
#include <winsock2.h>
#include <ws2tcpip.h>
#endif
#ifndef _WIN32
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#endif


#define LOG_PREFIX "socket-logic"

#define RESPONSE_DELAY_US 2000000

#define NUM_CHANNELS		18
#define NUM_TRIGGER_STAGES	8
#define CLOCK_RATE			SR_MHZ(100)
#define MIN_NUM_SAMPLES		4
#define DEFAULT_SAMPLERATE	SR_KHZ(200)

/* Command opcodes */
#define CMD_RESET           0
#define CMD_INIT            1
#define CMD_NONE            2
#define CMD_WAIT_TRIGGER    3
#define CMD_NEXT_BUF        4
#define CMD_COMPLETE        5
#define CMD_ID              6

#define CMD_ARM_ON_STEP     7
#define CMD_SET_VALUE       8
#define CMD_SET_RANGE       9
#define CMD_SET_VMASK       10
#define CMD_SET_EDGE        11
#define CMD_SET_EMASK       12
#define CMD_SET_CONFIG      13
#define CMD_SET_SERIALOPTS  14
#define CMD_SET_POSTCOUNT   15
#define CMD_SAMPLE_RATE     16
#define CMD_SET_PRECOUNT	17

#define RESP_RESET          0
#define RESP_INIT           1
#define RESP_NONE           2
#define RESP_ACQ            3
#define RESP_FIFO_TX        4
#define RESP_WAITING        5
#define RESP_DONE           6

#define RESP_ARM_ON_STEP    7
#define RESP_SET_VALUE      8
#define RESP_SET_RANGE      9
#define RESP_SET_VMASK      10
#define RESP_SET_EDGE       11
#define RESP_SET_EMASK      12
#define RESP_SET_CONFIG     13
#define RESP_SET_SERIALOPTS 14
#define RESP_SET_POSTCOUNT  15
#define RESP_SAMPLE_RATE    16
#define RESP_SET_PRECOUNT	17

/* Trigger config */
#define TRIGGER_START              (1 << 3)

/* Bitmasks for CMD_FLAGS */
/* 12-13 unused, 14-15 RLE mode (we hardcode mode 0). */
#define FLAG_INTERNAL_TEST_MODE    (1 << 11)
#define FLAG_EXTERNAL_TEST_MODE    (1 << 10)
#define FLAG_SWAP_CHANNELS           (1 << 9)
#define FLAG_RLE                   (1 << 8)
#define FLAG_SLOPE_FALLING         (1 << 7)
#define FLAG_CLOCK_EXTERNAL        (1 << 6)
#define FLAG_CHANNELGROUP_4        (1 << 5)
#define FLAG_CHANNELGROUP_3        (1 << 4)
#define FLAG_CHANNELGROUP_2        (1 << 3)
#define FLAG_CHANNELGROUP_1        (1 << 2)
#define FLAG_FILTER                (1 << 1)
#define FLAG_DEMUX                 (1 << 0)

#define LENGTH_BYTES 4
 struct tcp_socket {
	char *address;
	char *port;
	int socket;
	char length_buf[LENGTH_BYTES];
	int length_bytes_read;
	int response_length;
	int response_bytes_read;
};

struct trigger_config {
	uint8_t trigger_on;
	struct trigger_stage_config *stages;
	uint8_t num_stages;
};

struct trigger_stage_config {
	uint8_t arm_on_step;
	uint16_t value;
	uint16_t range;
	uint16_t vmask;
	uint16_t edge;
	uint16_t emask;
	uint16_t delay;
	uint8_t repetitions;
	uint8_t data_ch;
	uint8_t clock_ch;
	uint8_t cycle_delay;
	uint8_t format;
};


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

	uint16_t flag_reg;
	uint16_t device_mode;
	uint64_t timebase;
	uint64_t buffersize;
	uint16_t trigger_source;
	uint16_t trigger_slope;
	int32_t num_vdiv;
	uint16_t coupling;
	GSList *analog_channels;
	GSList *logic_channels;

	struct trigger_config *trigger;

	/* Operational states */
	unsigned int num_transfers;
	unsigned int num_samples;
	unsigned int num_frames;
	int num_bytes;
	int cnt_bytes;
	int cnt_samples;



	uint64_t last_limit_samples0;
	uint64_t last_limit_samples1;


	/* Temporary variables */

	unsigned char sample[2];
	unsigned char tmp_sample[2];
	unsigned char *raw_sample_buf;
	int stopped;
};


SR_PRIV extern const char *socket_logic_channel_names[NUM_CHANNELS+1];

SR_PRIV int socket_logic_send_shortcommand(struct tcp_socket *tcp,
		uint8_t command);
SR_PRIV int socket_logic_send_longcommand(struct tcp_socket *tcp,
		uint8_t command, uint8_t *data);

SR_PRIV int tcp_open(void *priv);

SR_PRIV int tcp_source_add(struct sr_session *session, void *priv,
		int events, int timeout, sr_receive_data_callback cb, void *cb_data);

SR_PRIV int tcp_source_remove(struct sr_session *session, void *priv);

SR_PRIV int tcp_send(void *priv, const char *command);

SR_PRIV int tcp_raw_read_data(void *priv, unsigned char *buf, int maxlen);

SR_PRIV int tcp_close(void *priv);

SR_PRIV void tcp_free(void *priv);

SR_PRIV void socket_logic_channel_mask(const struct sr_dev_inst *sdi);

SR_PRIV struct dev_context *socket_logic_dev_new(void);

SR_PRIV void socket_logic_abort_acquisition(const struct sr_dev_inst *sdi);

SR_PRIV void socket_logic_stop(const struct sr_dev_inst *sdi);

SR_PRIV int socket_logic_receive_data(int fd, int revents, void *cb_data);



#endif
