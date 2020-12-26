%option noyywrap

/* Sección de declaraciones */
%{
#include <iostream>
#include <fstream>
#include <string>

using namespace std;

int pos;

ifstream in;
ofstream out;
istream* p_in;
string filename_in, filename_out, ext;
int n;

string substr(const char* s, size_t pos, size_t len = string::npos);
%}

/* Alias */
BOLD			\*\*(.)*\*\*
ITALIC			\*(.)*\*
STRIKETHROUGH	\~\~(.)*\~\~
BLOCKQUOTE		^(\>)
CODE_1			^(```)(```)$
CODE_2			``(.)*``
LINK			\[.*\]\("http://".*\)
LINE			("* * *")|^("---")\-*|^("- - -")\-*

HEADING_1		^#
HEADING_2		^(#{2})
HEADING_3		^(#{3})
HEADING_4		^(#{4})
HEADING_5		^(#{5})
HEADING_6		^(#{6})

%%
 /* Sección de reglas */

{BOLD}			{
	out << "<b>" << substr(yytext, 2, yyleng - 4) << "</b>";
}

{ITALIC}		{
	out << "<i>" << substr(yytext, 1, yyleng - 2) << "</i>";
}

{STRIKETHROUGH}	{
	out << "<del>" << substr(yytext, 2, yyleng - 4) << "</del>";
}

{BLOCKQUOTE}	{
	out << "<blockquote>" << substr(yytext, 1) << "</blockquote>";
}

{LINK}			{
	/*
	pos = yytext.rfind("http");
	nombre_link = substr(yytext, 1,pos-3);
	link = substr(yytext, pos,yytext.size()-2);
	out << "<a href=\"" + link + "\">" + nombre_link + "</a>";
	*/
}

{LINE}			{
	out << "<hr>" << endl;
}

{CODE_1} 		{
	out << "<code>" << substr(yytext, 3, yyleng - 4) << "</code>";
}

{CODE_2}		{
	out << "<code>" << substr(yytext, 2, yyleng - 3) << "</code>";
}

{HEADING_1}		{
	out << "<h1>" << substr(yytext, 1) << "</h1>" << endl;
}

{HEADING_2}		{
	out << "<h2>" << substr(yytext, 2) << "</h2>" << endl;
}

{HEADING_3}		{
	out << "<h3>" << substr(yytext, 3) << "</h3>" << endl;
}

{HEADING_4}		{
	out << "<h4>" + substr(yytext, 4) + "</h4>" << endl;
}

{HEADING_5}		{
	out << "<h5>" + substr(yytext, 5) + "</h5>" << endl;
}

{HEADING_6}		{
	out << "<h6>" + substr(yytext, 6) + "</h6>" << endl;
}


%%

/* Sección de procedimientos */

string substr(const char* s, size_t pos, size_t len) {
	string str(s);
	return str.substr(pos, len);
}

int main(int argc, char** argv) {
	if (argc >= 2) {
		// comprobamos si es un fichero markdown
		filename_in = argv[1];
		n = filename_in.rfind('.');
		ext = filename_in.substr(n);
		if (ext != ".md"){
			cerr << "Error. El fichero " << filename_in << " no es un fichero markdown" << endl;
			exit(1);
		}

		// abrimos el fichero
		in.open(argv[1]);
		if (!in) {
			cerr << "Error abriendo archivo de entrada " << argv[1] << endl;
			exit(1);
		}
		p_in = &in;
		filename_out = filename_in.substr(0,n);
		filename_out += ".html";

	} else {
		filename_out = "out.html";
		p_in = &cin;
	}

	// creamos el fichero html
	out.open(filename_out);
	if (!out) {
		cerr << "Error abriendo archivo de salida " << filename_out << endl;
		exit(1);
	}

	yyFlexLexer flujo(p_in, &out);
	flujo.yylex();
	cout << "Fin" << endl;
	out.close();
	in.close();

	return 0;
}
