.so Tmac.mm-etc
.if t .Newcentury-fonts
.INITR* \n[.F]
.SIZE 12 14
.TITLE "Client/server \[em] starter code description"
.RCS "$Id: asg4-cxi-cxid-code.mm,v 1.60 2022-02-19 18:25:14-08 - - $"
.PWD
.URL
.EQ
delim $$
.EN
.hw ac-cu-mu-la-ted
.de V=br
.   V= \\$@
.   br
..
.de ALPHAS
.   ALX a ()
..
.de BULLETS
.   ALX \[bu] 0 4 0 0
..
.de COMMAND
.   LI "\f[CB]\\$[1]\0\f[I]\\$[2]\f[R]" \\$[3]
..  
.de MESSAGE
.   LI "\f[CB]\\$[1]\0\f[R]\\$[2]" \\$[3]
..
.de MODULE
.   LI "\f[CB]\\$[1]\f[P]"
..
Some code has been provided in several modules.
.H 1 "\f[CB]debug.{h,cpp}\fP"
As in previous assignments.
.H 1 "\f[CB]logstream.h\fP
Is a wrapper for an
.V= ostream
that can be used to print debugging information,
but prefixes each output line with the execname and the process id.
Since all code is in the header file, a
.V= cpp
files is not needed.
.P
Usage\(::
Declare a variable such as
.V= "logstream outlog (cout);".
.br
Then use it in the same way as 
.V= cout \(::
.VTCODE* 1 "outlog << \fP.....\f[CB] << endl;"
The execname and process id (pid)
via
.V= getpid (2)
is printed followed by whatever else is to be printed,
represented by the \&.....\& above.
.P
The operator
.VTCODE* 1 "template <typename T>"
.VTCODE* 1 "ostream& operator<< (const T& obj)"
is a template so that its right operand can be of any type that
.V= ostreeam::operator<<
can accept as a right operand.
.P
The field
.VTCODE* 1 "ostream& out_;"
is a reference, not a value because objects of type
.V= ostream
can not be copied.
Note also that the ctor initializes it by using a field intializer.
It can not be initialized by
.V= operator=
inside the body of the ctor.
.bp
.H 1 "\f[CB]protocol.{h,cpp}"\fP
Implements the protocol that interacts between client and server.
The
.V= cxi_header
is precisely defined,
along with the enum class
.V= cxi_commands
to be used in communication.
.ALPHAS
.LI
.V=br static_assert
verifies the exact size of the header,
and
.V= uint32_t
specifies that the count field is exactly 32 bits.
This limits packet size to 4,294,967,296 bytes,
but that is more than large enough for a student project.
.P
.V= static_assert
is determined at compile time and causes the compilation to be
rejected if its argument is false.
An
.V= assert ,
on the other hand,
is a macro whose argument is tested at runtime.
.LI
.V=br send_packet
expects a socket and a buffer and loops using the socket's send
until the entire message is sent.
.LI
.V=br recv_packet
uses socket's recv and receive a message.
It is expected that the buffer thus passed in is large enough
to accept the message.
.LI
.V=br operator<<
is for debug printing the header and checking for network or
host byte order errors in the header.
.LE
.P
.E= Warning\(::
Some strange errors will occur that will possibly lead to deadlock
between the client and the server,
or other strange occurrences,
if you forget to use
.V= ntohl
and
.V= htonl
when communicating between the client and the server.
.bp
.H 1 "\f[CB]socket.{h,cpp}\fP \[em] \f[CB]base_socket\fP"
Is a wrapper around the more cumbersome standard C interface to
sockets.
It wraps a socket file descriptor.
.V= base_socket
defines all of the communication functions.
No inheritance is used,
but it is convenient to separate the user interfaces into
separate purposes.
.P
Most of its functions are
.V= protected
and may only be used by the
subclasses.
Since the ctor and dtor are protected,
users are prohibited from declaring a
.V= base_socket .
Program code in the client, daemon, and server only declare
objects of the subclasses.
.P
.ne 10
The field values are\(::
.ALPHAS
.LI
.V=br "int socket_fd"
file descriptor (small integer) returned by the
.V= socket
system call.
.LI
.V=br sockaddr_in
containing the connection information for communication.
Its fields are\(::
.BULLETS
.LI
.V= "sa_family_t sin_family" \(::
address family\(::
.V= AF_INET 
.LI
.V= "in_port_t sin_port" \(::
net byte order
.V= uint16_t 
port number
.LI
.V= "struct in_addr sin_addr" \(::
net byte order
.V= uint32_t 
internet address
.LE
.LE
.P
Since these have access to operating system facilities,
the copiers and movers have been declared as
.V= =delete .
.P
The following functions are inherited by the derived classes
and may be used by them.
As memtioned previously,
the user may not instantiate this class directly.
The available functions are\(::
.ALPHAS
.LI
.V=br "void close();"
Close the socket.
The destructor automatically closes a socket,
sot this may be little redundant.
.LI
.V=br "ssize_t send (const void* buffer, size_t bufsize);"
Send a message to the socket, returning the number of bytes
actually sent.
.LI
.V=br "ssize_t recv (void* buffer, size_t bufsize);"
Receive a message from a buffer of the given size,
reporting the number of bytes actually received.
.LI
.V=br "friend string to_string (const base_socket& sock);"
A debugging format function.
.LE
.bp
.H 1 "\f[CB]socket.{h,cpp}\fP \[em] user interface"
The user interface functions specialize the uses of a base socket
for particular purposes.
Only the constructors differ in the way the socket is created.
Usage for all of the is by send and receive.
.ALPHAS
.LI
.V=br server_socket
is used by the daemon,
and perhaps should have been named the daemon socket instead.
.BULLETS
.LI
Create a socket for communication on a specific server port.
.LI
Bind the socket to the specific part.
.LI
Listen for a connection request from a client,
which is then accepted.
.LE
.LI
.V= accepted_socket
.BULLETS
.LI
Created by a server accepting a call from a client
and used by the server sub-process to communicate with a client.
.LE
.LI
.V=br client_socket
is used by a client in an attempt to connect to a server.
.BULLETS
.LI
Creates a socket to request the connection.
.LI
Attempts to connect to a server,
given a particular host and port.
.LE
.LE
.bp
.H 1 "\f[CB]cxi.cpp"\fP
is the client code.
It reads commands from the input and interprets each command
as needed by sending a packet to the server.
It has the client's main loop
and calls a separate function for each of the client commands.
.ALPHAS
.LI
.V=br cxi_ls
example function which shows to the client interacts with the server.
Implements the
.V= ls
command.
.LI
.V=br make_unique
The statement
.VTCODE* 1 "auto buffer = make_unique<char[]> (host_nbytes + 1);"
creates a
.V= unique_ptr
pointing to a buffer of the appropriate size.
This buffer is automatically freed when the pointer goes out of scope.
The size of the buffer is known in advance,
having been received in the header.
In the case of loading a file,
the
.V= stat (2)
system call can determine the size of a file.
.LI
.V=br stat (2)
.VTCODE* 1 "struct stat stat_buf;"
.VTCODE* 1 "int status = stat (filename, &stat_buf);"
will enquire as the the status of the given filename.
If the result is 0, then
.V= stat_buf.st_size
contains the number of bytes in the file.
Note that
.V= filename
is a 
.V= "const char*" ,
not a
.V= string .
.LI
If a system call fails, an error is reported to the standard error
in the usual manner, and the exit status for the program is set to
.V= EXIT_FAILURE .
.br
.IR "execname: filename: reason"
.BULLETS
.LI
.IR execname
is always the
.V= basename (3)
of the program being run (derived from
.V= argv[0] ).
.LI
.IR filename
is the name of the file or other object that could not be accessed.
.LI
.IR reason
is the explanation of the problem from
.V= strerror(errno).
.LE
.LE
.bp
.H 1 "\f[CB]cxid.cpp\fP \[em] daemon"
Is both the daemon and server code in one program,
but multiple processes.
The daemon creates a
.V= server_socket
which is used to listen for a client connection.
When a client connects, 
.V= fork (2)
is used to create a child process to execute the server code.
It also reaps zombie processes which are servers from which
a client has disconnected.
There is a separate server process for each client that connects.
.ALPHAS
.LI
.V=br main
The main function sets up a signal action and a server socket
to listen for a client.
Whenever a client connects, it forks a child process to preform
the server task.
It is an infinite loop and will run until killed at the terminal.
.LI
.V=br reap_zombies
when a child process exits,
it becomes a zombie until the parent waits for it or until the
parent exits.
But the daemon is in an infinite loop,
so it uses
.V= waitpid (2)
to report the status of the child process,
thus removing the child server from the process table.
.LI
.V=br fork_cxiserver
Use
.V= fork (2)
to run the server.
It must close the unused sockets
(the server in the child and the accepted socket in the parent).
.LE
.H 1 "\f[CB]cxid.cpp\fP \[em] server"
contains the run_server process, which loops reading commands
from the client,
acting on those commands,
then sending back a reply.
It runs in an infinite loop,
exiting only when the client disconnects.
.ALPHAS
.LI
.V=br run_server
is the child process that waits for a command from the client
and then replies as appropriate.
It continues until the client disconnects,
at which time the server exits.
.LI
.V=br reply_ls
is an example of how to reply to a client.
It uses
.V= popen (3)
to create a pipe to
.V= ls (1)
to list the files in the server's directory.
Then it sends the information to the client.
.LE
