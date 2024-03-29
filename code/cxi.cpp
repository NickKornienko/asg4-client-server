// $Id: cxi.cpp,v 1.6 2021-11-08 00:01:44-08 - - $
// James Garrett jaagarre
// Nick Kornienko nkornien

#include <iostream>
#include <ostream>
#include <fstream>
#include <sstream>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>
using namespace std;

#include <libgen.h>
#include <sys/types.h>
#include <unistd.h>

#include "debug.h"
#include "logstream.h"
#include "protocol.h"
#include "socket.h"

logstream outlog(cout);
struct cxi_exit : public exception
{
};

unordered_map<string, cxi_command> command_map{
    {"exit", cxi_command::EXIT},
    {"help", cxi_command::HELP},
    {"ls", cxi_command::LS},
    {"rm", cxi_command::RM},
    {"get", cxi_command::GET},
    {"put", cxi_command::PUT}};

static const char help[] = R"||(
exit         - Exit the program.  Equivalent to EOF.
get filename - Copy remote file to local host.
help         - Print help summary.
ls           - List names of files on remote server.
put filename - Copy local file to remote host.
rm filename  - Remove file from remote server.
)||";

void cxi_help()
{
   cout << help;
}

void cxi_ls(client_socket &server)
{
   cxi_header header;
   header.command = cxi_command::LS;
   send_packet(server, &header, sizeof header);
   recv_packet(server, &header, sizeof header);
   if (header.command != cxi_command::LSOUT)
   {
      outlog << "sent LS, server did not return LSOUT" << endl;
      outlog << "server returned " << header << endl;
   }
   else
   {
      size_t host_nbytes = ntohl(header.nbytes);
      auto buffer = make_unique<char[]>(host_nbytes + 1);
      recv_packet(server, buffer.get(), host_nbytes);
      buffer[host_nbytes] = '\0';
      cout << buffer.get();
   }
}

void cxi_rm(client_socket &server, string file)
{
   cxi_header header;
   header.command = cxi_command::RM;
   strcpy(header.filename, file.c_str());

   send_packet(server, &header, sizeof header);
   recv_packet(server, &header, sizeof header);

   if (header.command != cxi_command::ACK)
   {
      outlog << "Error: Cannot remove: " << file << endl;
   }
   else
   {
      outlog << "File: " << file << " removed" << endl;
   }
}

void cxi_get(client_socket &server, string file)
{
   if (file.find('/') != std::string::npos || file.length() > 58)
   {
      outlog << "Error: Invalid file name: " << file << endl;
      return;
   }

   cxi_header header;
   header.command = cxi_command::GET;
   strcpy(header.filename, file.c_str());

   send_packet(server, &header, sizeof header);
   recv_packet(server, &header, sizeof header);

   if (header.command != cxi_command::FILEOUT)
   {
      outlog << "Error: Cannot get: " << file << endl;
   }
   else
   {
      outlog << "Copied file: " << file << endl;

      ofstream ofile;
      try
      {
         ofile.open(file,
                    std::ofstream::out | std::ofstream::trunc);
      }
      catch (const std::exception &)
      {
         outlog << "Error: Cannot open file: " << file << endl;
         return;
      }

      size_t host_nbytes = ntohl(header.nbytes);
      if (host_nbytes > 0)
      {
         auto buffer = make_unique<char[]>(host_nbytes + 1);
         recv_packet(server, buffer.get(), host_nbytes);
         buffer[host_nbytes] = '\0';
         ofile.write(buffer.get(), host_nbytes);
      }

      ofile.close();
   }
}

void cxi_put(client_socket &server, string file)
{
   if (file.find('/') != std::string::npos || file.length() > 58)
   {
      outlog << "Error: Invalid file name: " << file << endl;
      return;
   }

   cxi_header header;
   header.command = cxi_command::PUT;
   strcpy(header.filename, file.c_str());

   ifstream ofile(file);
   if (!ofile.is_open())
   {
      outlog << "Error: Cannot open file: " << file << endl;
      return;
   }

   ofile.seekg(0, ofile.end);
   int size = ofile.tellg();
   ofile.seekg(0, ofile.beg);

   char *buffer = new char[size];
   ofile.read(buffer, size);
   ofile.close();

   header.nbytes = htonl(size);
   send_packet(server, &header, sizeof header);
   send_packet(server, buffer, size);

   recv_packet(server, &header, sizeof header);
   delete[] buffer;

   if (header.command != cxi_command::ACK)
   {
      outlog << "Error: Could not open remote file: " << file << endl;
   }
   else
   {
      outlog << "Wrote to remote file: " << file << endl;
   }
}

void usage()
{
   cerr << "Usage: " << outlog.execname() << " host port" << endl;
   throw cxi_exit();
}

pair<string, in_port_t> scan_options(int argc, char **argv)
{
   for (;;)
   {
      int opt = getopt(argc, argv, "@:");
      if (opt == EOF)
         break;
      switch (opt)
      {
      case '@':
         debugflags::setflags(optarg);
         break;
      }
   }
   if (argc - optind != 2)
      usage();
   string host = argv[optind];
   in_port_t port = get_cxi_server_port(argv[optind + 1]);
   return {host, port};
}

int main(int argc, char **argv)
{
   outlog.execname(basename(argv[0]));
   outlog << to_string(hostinfo()) << endl;
   try
   {
      auto host_port = scan_options(argc, argv);
      string host = host_port.first;
      in_port_t port = host_port.second;
      outlog << "connecting to " << host << " port " << port << endl;
      client_socket server(host, port);
      outlog << "connected to " << to_string(server) << endl;
      for (;;)
      {
         string line;
         getline(cin, line);
         if (cin.eof())
            throw cxi_exit();

         string segment;
         vector<string> tokens;
         istringstream stream(line);
         while (getline(stream, segment, ' '))
            tokens.push_back(segment);

         const auto &itor = command_map.find(tokens[0]);
         cxi_command cmd = itor == command_map.end()
                               ? cxi_command::ERROR
                               : itor->second;
         switch (cmd)
         {
         case cxi_command::EXIT:
            throw cxi_exit();
            break;
         case cxi_command::HELP:
            cxi_help();
            break;
         case cxi_command::LS:
            cxi_ls(server);
            break;
         case cxi_command::RM:
            cxi_rm(server, tokens[1]);
            break;
         case cxi_command::GET:
            cxi_get(server, tokens[1]);
            break;
         case cxi_command::PUT:
            cxi_put(server, tokens[1]);
            break;
         default:
            outlog << line << ": invalid command" << endl;
            break;
         }
      }
   }
   catch (socket_error &error)
   {
      outlog << error.what() << endl;
   }
   catch (cxi_exit &error)
   {
      DEBUGF('x', "caught cxi_exit");
   }
   return 0;
}
