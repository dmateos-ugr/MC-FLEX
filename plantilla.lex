%option noyywrap

/* Sección de declaraciones */
%{
#include <iostream>
#include <fstream>
#include <string>
#include <map>

using namespace std;

ifstream fichero;
istream* in;
bool next_dst = false;
bool line_finished = false;
string src, dst;
struct info_t {
	int num_packets;
	int total_size;
};
ostream& operator<<(ostream&, const info_t&);
map<pair<string, string>, info_t> packets;
%}

/* Alias */
DIGITO_DEC	[0-9]
DIGITO_HEX	[0-9A-Fa-f]
INT			{DIGITO_DEC}+
FLOAT		{INT}.{INT}
PAD			" "*
MAC			({DIGITO_HEX}{1,2}\:){5}{DIGITO_HEX}{1,2}

/* Regex for IPv4 */
DEC_SUC		(25[0-5])|(2[0-4][0-9])|(1?[0-9]?[0-9])
IPV4		({DEC_SUC}{1,3}\.){3}{DEC_SUC}{1,3}

/* Regex for IPv6 */
HEX_SUC		{DIGITO_HEX}{1,4}
IPV6_0		({HEX_SUC}\:){7}{HEX_SUC}
IPV6_1		({HEX_SUC}\:){1,7}\:
IPV6_2		({HEX_SUC}\:){1,6}(\:{HEX_SUC}){1,1}
IPV6_3		({HEX_SUC}\:){1,5}(\:{HEX_SUC}){1,2}
IPV6_4		({HEX_SUC}\:){1,4}(\:{HEX_SUC}){1,3}
IPV6_5		({HEX_SUC}\:){1,3}(\:{HEX_SUC}){1,4}
IPV6_6		({HEX_SUC}\:){1,2}(\:{HEX_SUC}){1,5}
IPV6_7		({HEX_SUC}\:){1,1}(\:{HEX_SUC}){1,6}
IPV6_8		\:(\:{HEX_SUC}){1,7}
IPV6_9		\:\:
IPV6		{IPV6_1}|{IPV6_2}|{IPV6_2}|{IPV6_3}|{IPV6_4}|{IPV6_5}|{IPV6_6}|{IPV6_7}|{IPV6_8}|{IPV6_9}

ADDR		{MAC}|{IPV4}|{IPV6}
INICIO_LINE	{PAD}{INT}{PAD}{FLOAT}{PAD}{FLOAT}{PAD}
LINE_IPV4	^{INICIO_LINE}{IPV4}" → "{IPV4}

%%
 /* Sección de reglas */

^{INICIO_LINE}	{ cout << "inicio line" << endl; next_dst = false; line_finished = false; }
{ADDR}		{
	if (line_finished)
		continue;
	if (!next_dst) {
		src = yytext;
		next_dst = true;
	} else {
		dst = yytext;
		packets[{src, dst}].num_packets++;
		line_finished = true;
	}
	cout << "Addr: " << yytext << " at line " << lineno() << endl;
}
.		{}

%%

/* Sección de procedimientos */
ostream& operator<<(ostream& os, const info_t& info) {
	os << "Number of packets: " << info.num_packets << endl;
	os << "Total size (bytes): " << info.total_size << endl;
	return os;
}

int main(int argc, char** argv) {
	if (argc == 2) {
		fichero.open(argv[1]);
		if (!fichero) {
			cerr << "Error abriendo fichero " << argv[1] << endl;
			exit(1);
		}
		in = &fichero;
	} else {
		in = &cin;
	}
	cout << "gogo" << endl;

	yyFlexLexer flujo(in, 0);
	flujo.yylex();

	cout << "Packets: " << packets.size() << endl;
	for (auto v : packets) {
		cout << "[" << v.first.first << " to " << v.first.second << "]" << endl
		     << v.second << endl;
	}
	return 0;
}
