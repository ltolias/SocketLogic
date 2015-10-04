#include <stdio.h>
#include <string.h>    //strlen
#include <sys/socket.h>
#include <arpa/inet.h> //inet_addr
#include <netinet/tcp.h>
#include <unistd.h>    //write
#include <netdb.h>

#include <termios.h>
#include <stdlib.h> 

#include <fcntl.h>              //Needed for SPI port
#include <sys/ioctl.h>          //Needed for SPI port
//#include <linux/spi/spidev.h>   //Needed for SPI port
#include <stdio.h>
#include <stdlib.h>
#include <string.h>



int spi_cs0_fd;             //file descriptor for the SPI device
int spi_cs1_fd;             //file descriptor for the SPI device
unsigned char spi_mode;
unsigned char spi_bitsPerWord;
unsigned int spi_speed;



#define MSG_LENGTH_SERVER 10000//131072
#define MSG_LENGTH_CLIENT 200//120

#define SPI_SPEED 1000000

int socket_desc , client_sock , c , read_size;
struct sockaddr_in server , client;
int port;
char client_message[MSG_LENGTH_CLIENT];
char client_message_comp[MSG_LENGTH_CLIENT];
char server_message[MSG_LENGTH_SERVER];


void openSocket()
{

    //Create socket
    socket_desc = socket(AF_INET , SOCK_STREAM , IPPROTO_TCP); 
    if (socket_desc == -1)
    {
        printf("Could not create socket");
    }
    puts("Socket created");
     
    //Prepare the sockaddr_in structure
    server.sin_family = AF_INET;
    server.sin_addr.s_addr = INADDR_ANY;
    server.sin_port = htons( port );
     
    //Bind
    if( bind(socket_desc,(struct sockaddr *)&server , sizeof(server)) < 0)
    {
        //print the error message
        perror("bind failed. Error");
        return;
    }
    puts("bind done");
     
    //Listen
    listen(socket_desc , 5);
     
    //Accept and incoming connection
    puts("Waiting for incoming connections...");
    c = sizeof(struct sockaddr_in);
}


#define NB_ENABLE 0
#define NB_DISABLE 1




void nonblock(int state)
{
    struct termios ttystate;

    //get the terminal state
    tcgetattr(STDIN_FILENO, &ttystate);

    if (state==NB_ENABLE)
    {
        //turn off canonical mode
        ttystate.c_lflag &= ~ICANON;
        //minimum of number input read.
        ttystate.c_cc[VMIN] = 1;
    }
    else if (state==NB_DISABLE)
    {
        //turn on canonical mode
        ttystate.c_lflag |= ICANON;
    }
    //set the terminal attributes.
    tcsetattr(STDIN_FILENO, TCSANOW, &ttystate);

}

int kbhit()
{
    struct timeval tv;
    fd_set fds;
    tv.tv_sec = 0;
    tv.tv_usec = 0;
    FD_ZERO(&fds);
    FD_SET(STDIN_FILENO, &fds); //STDIN_FILENO is 0
    select(STDIN_FILENO+1, &fds, NULL, NULL, &tv);
    return FD_ISSET(STDIN_FILENO, &fds);
}


/*
//spi_device    0=CS0, 1=CS1
int SpiOpenPort (int spi_device)
{
    int status_value = -1;
    int *spi_cs_fd;


    //----- SET SPI MODE -----
    //SPI_MODE_0 (0,0)  CPOL = 0, CPHA = 0, Clock idle low, data is clocked in on rising edge, output data (change) on falling edge
    //SPI_MODE_1 (0,1)  CPOL = 0, CPHA = 1, Clock idle low, data is clocked in on falling edge, output data (change) on rising edge
    //SPI_MODE_2 (1,0)  CPOL = 1, CPHA = 0, Clock idle high, data is clocked in on falling edge, output data (change) on rising edge
    //SPI_MODE_3 (1,1)  CPOL = 1, CPHA = 1, Clock idle high, data is clocked in on rising, edge output data (change) on falling edge
    spi_mode = SPI_MODE_0;
    
    //----- SET BITS PER WORD -----
    spi_bitsPerWord = 8;
    
    //----- SET SPI BUS SPEED -----
    spi_speed = SPI_SPEED;        //1000000 = 1MHz (1uS per bit) 


    if (spi_device)
        spi_cs_fd = &spi_cs1_fd;
    else
        spi_cs_fd = &spi_cs0_fd;


    if (spi_device)
        *spi_cs_fd = open(std::string("/dev/spidev0.1").c_str(), O_RDWR);
    else
        *spi_cs_fd = open(std::string("/dev/spidev0.0").c_str(), O_RDWR);

    if (*spi_cs_fd < 0)
    {
        perror("Error - Could not open SPI device");
        exit(1);
    }

    status_value = ioctl(*spi_cs_fd, SPI_IOC_WR_MODE, &spi_mode);
    if(status_value < 0)
    {
        perror("Could not set SPIMode (WR)...ioctl fail");
        exit(1);
    }

    status_value = ioctl(*spi_cs_fd, SPI_IOC_RD_MODE, &spi_mode);
    if(status_value < 0)
    {
      perror("Could not set SPIMode (RD)...ioctl fail");
      exit(1);
    }

    status_value = ioctl(*spi_cs_fd, SPI_IOC_WR_BITS_PER_WORD, &spi_bitsPerWord);
    if(status_value < 0)
    {
      perror("Could not set SPI bitsPerWord (WR)...ioctl fail");
      exit(1);
    }

    status_value = ioctl(*spi_cs_fd, SPI_IOC_RD_BITS_PER_WORD, &spi_bitsPerWord);
    if(status_value < 0)
    {
      perror("Could not set SPI bitsPerWord(RD)...ioctl fail");
      exit(1);
    }

    status_value = ioctl(*spi_cs_fd, SPI_IOC_WR_MAX_SPEED_HZ, &spi_speed);
    if(status_value < 0)
    {
      perror("Could not set SPI speed (WR)...ioctl fail");
      exit(1);
    }

    status_value = ioctl(*spi_cs_fd, SPI_IOC_RD_MAX_SPEED_HZ, &spi_speed);
    if(status_value < 0)
    {
      perror("Could not set SPI speed (RD)...ioctl fail");
      exit(1);
    }
    return(status_value);
}


int SpiClosePort (int spi_device)
{
    int status_value = -1;
    int *spi_cs_fd;

    if (spi_device)
        spi_cs_fd = &spi_cs1_fd;
    else
        spi_cs_fd = &spi_cs0_fd;


    status_value = close(*spi_cs_fd);
    if(status_value < 0)
    {
        perror("Error - Could not close SPI device");
        exit(1);
    }
    return(status_value);
}



//data      Bytes to write.  Contents is overwritten with bytes read.
int SpiWriteAndRead (int spi_device, unsigned char *data, int length)
{
    struct spi_ioc_transfer spi[length];
    int i = 0;
    int retVal = -1;
    int *spi_cs_fd;

    if (spi_device)
        spi_cs_fd = &spi_cs1_fd;
    else
        spi_cs_fd = &spi_cs0_fd;

    //one spi transfer for each byte

    for (i = 0 ; i < length ; i++)
    {
        spi[i].tx_buf        = (unsigned long)(data + i); // transmit from "data"
        spi[i].rx_buf        = (unsigned long)(data + i) ; // receive into "data"
        spi[i].len           = sizeof(*(data + i)) ;
        spi[i].delay_usecs   = 0 ;
        spi[i].speed_hz      = spi_speed ;
        spi[i].bits_per_word = spi_bitsPerWord ;
        spi[i].cs_change = 0;
    }

    retVal = ioctl(*spi_cs_fd, SPI_IOC_MESSAGE(length), &spi) ;

    if(retVal < 0)
    {
        perror("Error - Problem transmitting spi data..ioctl");
        exit(1);
    }

    return retVal;
}

*/

struct trigger_conf_t
{
   int delay;   // wait delay samples on match
   int level;   // ?
   int channel; // channel to use in serial mode
   int serial;  // 1: serial mode on channel
   int start;   // 1: start capture on match
   uint16_t values; // trigger values
   uint16_t mask;  // trigger mask
};

struct sampler_t
{
   int divider;  // sampling freq = clock / (divider + 1)
   int readcnt4; // total number of samples to send (divided by 4)
   int delaycnt4;// number of samples after the trigger to send (divided by 4)
   int demux;    // ?
   int filter;   // ?
   int groups;   // channels to include in transmission. Bit 0,1,2,3 each represent 8 channels
   int external; // external clock - not used
   int inverted; // external clock inverter - not used
};

#define NUM_STAGES 8

struct trigger_conf_t trigger[NUM_STAGES];
struct sampler_t sampler;


uint32_t total_samples = 0;
uint32_t arg_sum = 0;
uint8_t arguments[4];
uint8_t command = 0;
uint32_t samplerate = 0;
int compindex = 0;
int i = 0;
int stage;

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
#define CMD_SET_LIMIT       15
#define CMD_SAMPLE_RATE     16

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
#define RESP_SET_LIMIT      15
#define RESP_SAMPLE_RATE    16


#define SPI_BUFF_LEN 4096 + 1

unsigned char spi_data[SPI_BUFF_LEN];

static unsigned char read_data[5] = {0x00,0x00,0x00,0x00,0x00};

void write_reg(unsigned char reg, unsigned char a0, unsigned char a1, unsigned char a2, unsigned char a3)
{
    unsigned char data[5] = {(reg | 0xc0),a0,a1,a2,a3};
    //SpiWriteAndRead(1, data, 5);
}
void send_command(unsigned char command)
{
    write_reg(0x00,0x00,0x00,0x00,command);
}
void read_reg(unsigned char reg)
{
    read_data[0] = (reg | 0x80);
    //SpiWriteAndRead(1, read_data, 5); 
}
void block_reg(unsigned char reg, unsigned char val)
{
    read_reg(reg);
    //while (read_data[4] != val)
    //    read_reg(reg);
}
void block_response(unsigned char response)
{
    block_reg(0x08, response);
}

const char *byte_to_binary(uint16_t x)
{
    static char b[17];
    b[0] = '\0';

    int z;
    for (z = 32768; z > 0; z >>= 1)
    {
        strcat(b, ((x & z) == z) ? "1" : "0");
    }

    return b;
}

unsigned char spii = 0;
unsigned char spij = 0;
void reload_spi_buff()
{

    for (int x = 0; x < SPI_BUFF_LEN-1; x+= 2)
    {

        spi_data[x+1] = spii;//spii;
        spi_data[x+2] = spij;//spij; 
        if (spii == 255)
            spij++;
        spii+= 1;

    }

}

void doStateMachine()
{
    printf("\tmessage: %s\n", client_message_comp);
    char to[2] = "ff";
    strncpy(to, client_message_comp, 2);
    sscanf(to, "%hhx", &command);

    //single byte commands
    if (command < 0x07)
    {
        if (command == CMD_RESET)
        {
            printf("\t\tcommand: RESET\n");
            send_command(CMD_RESET);
            block_response(RESP_RESET);
        }
        if (command == CMD_INIT)
        {
            printf("\t\tcommand: INIT\n");
            send_command(CMD_INIT);
            block_response(RESP_INIT);
        }

        if (command == CMD_ID)
        {
            printf("\t\tcommand: ID\n");
            //write_reg(WRITE0,0x00,0x00,0x00,CMD_ID);
            //while (read_reg(READ0)[4] != RESP_ID);
            sprintf(server_message, "SKLO");
            write(client_sock , server_message , strlen(server_message));
        }

        else if (command == CMD_WAIT_TRIGGER)
        {

            printf("\t\tcommand: RUN\n");

            send_command(CMD_WAIT_TRIGGER);

            int offset = (rand() % (int)(0.2*total_samples));
            spii = offset;
            spij = 0;
        
            int runs = total_samples*2 / (SPI_BUFF_LEN-1);
            runs += total_samples*2 % (SPI_BUFF_LEN-1) == 0 ? 0:1;

            for (int j = 0; j < runs; j++)
            {

                int tosend = SPI_BUFF_LEN;
                if (j == runs-1 && (total_samples*2) % (SPI_BUFF_LEN-1) != 0 )
                    tosend = (total_samples*2 % (SPI_BUFF_LEN-1)) + 1;

                block_response(RESP_WAITING);
                spi_data[0] = 0x03;
                //SpiWriteAndRead(1, spi_data, tosend);

                reload_spi_buff();
                //printf("\t\tsending: %d\n", tosend-1);
                write(client_sock , spi_data+1 , (int)(tosend-1));
               
                if (j != runs-1)
                    send_command(CMD_NEXT_BUF);
                else 
                    send_command(CMD_COMPLETE);
            }
           
        }

    }
    else //5 byte command
    {
        strncpy(to, client_message_comp+2, 2);
        sscanf(to, "%hhx", arguments);
        strncpy(to, client_message_comp+4, 2);
        sscanf(to, "%hhx", arguments+1);
        strncpy(to, client_message_comp+6, 2);
        sscanf(to, "%hhx", arguments+2);
        strncpy(to, client_message_comp+8, 2);
        sscanf(to, "%hhx", arguments+3);  
        arg_sum = arguments[0] + 256*arguments[1] + 256*256*arguments[2] + 256*256*256*arguments[3];
        //printf("%d\n", arg_sum);

        if (command == CMD_SET_LIMIT)
        {
            total_samples = arg_sum+1;
            write_reg(0x02,arguments[3],arguments[2],arguments[1],arguments[0]);
            printf("\t\tsamples: %d\n", total_samples);

        }
        else if (command == CMD_SAMPLE_RATE)
        {
            samplerate = arg_sum;   
            write_reg(0x03,arguments[3],arguments[2],arguments[1],arguments[0]);
            printf("\t\trate: %d\n", samplerate);
        }
        else  //just pass along the values and wait for a response
        {
            write_reg(0x01,arguments[3],arguments[2],arguments[1],arguments[0]);
            send_command(command);
            block_response(command);
        }
    }
}



int main(int argc , char *argv[])
{


    socket_desc = 0;
    client_sock = 0;
    c = 0;
    read_size = 0;
    int cont = 0;
    port = 8080;
    if (argc == 2)
        port = atoi(argv[1]);

    nonblock(NB_ENABLE);
    //SpiOpenPort(1);
    openSocket();
    sprintf(server_message, "1SLO");
    while (!cont)
    {
    
        //accept connection from an incoming client
        client_sock = accept(socket_desc, (struct sockaddr *)&client, (socklen_t*)&c);
        

       char hbuf[NI_MAXHOST], sbuf[NI_MAXSERV];

       if (getnameinfo((struct sockaddr *)&client, c, hbuf, sizeof(hbuf), sbuf, sizeof(sbuf), NI_NUMERICHOST | NI_NUMERICSERV) == 0)
           printf("Client Connected with host=%s, serv=%s\n", hbuf, sbuf);

        //setsockopt(client_sock, IPPROTO_TCP, TCP_NODELAY, (char *)&value, sizeof(int));

        read_size = recv(client_sock , client_message , MSG_LENGTH_CLIENT, 0);
        
        //Receive a message from client
        while( read_size > 0 && !cont)
        {
            char d;
            cont=kbhit();
            if (cont!=0)
            {
                d=fgetc(stdin);
                if (d=='q')
                {
                    cont=1;
                    close(client_sock);
                }
                else
                    cont=0;
            }
            //received();
            if (i == read_size)
            {
                read_size = recv(client_sock , client_message , MSG_LENGTH_CLIENT, 0);
                i = 0;
            }
            
            while (i < read_size)
            {
                if (client_message[i] == '\n')
                    break;
                else 
                    client_message_comp[compindex++] = client_message[i];
                i++;
            }
            if (i < read_size)
            {  
                client_message_comp[compindex] = '\0';
                doStateMachine();
                compindex = 0;
                i++;
            }

            char e;
            cont=kbhit();
            if (cont!=0)
            {
                e=fgetc(stdin);
                if (e=='q')
                    cont=1;
                else
                    cont=0;
            }

               
          
        }
         
        if(read_size == 0)
        {
            printf("Client disconnected\n");
            fflush(stdout);
        }
        else if(read_size == -1)
        {
            perror("recv failed");
        }
         
    }
    close(socket_desc);
    nonblock(NB_DISABLE);
    return 0;
}