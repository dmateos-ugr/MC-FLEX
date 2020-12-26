%option noyywrap

/* Sección de declaraciones */
%{
#include <iostream>
#include <fstream>
#include <string>

using namespace std;

ifstream in;
ofstream out;

string substr(const char* s, size_t pos, size_t len = string::npos);
%}

/* Alias */
BOLD			\*\*(.)*\*\*
ITALIC			\*(.)*\*
STRIKETHROUGH	\~\~(.)*\~\~
BLOCKQUOTE		^\>.*
CODE_1			^```(.|\n)*```$
CODE_2			``(.)*``
LINK			\[.*\]\(.*\)
LINE			("* * *")|^("---")\-*|^("- - -")\-*

HEADING_1		^#{1}.*
HEADING_2		^#{2}.*
HEADING_3		^#{3}.*
HEADING_4		^#{4}.*
HEADING_5		^#{5}.*
HEADING_6		^#{6}.*

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
	string s(yytext);
	int pos = s.find(']');
	string text = s.substr(1, pos - 1);
	string link = s.substr(pos+2, yyleng - (pos + 2) - 1);
	out << "<a href=\"" + link + "\">" + text + "</a>";
}

{LINE}			{
	out << "<hr>" << endl;
}

{CODE_1} 		{
	out << "<code>" << substr(yytext, 3, yyleng - 6) << "</code>";
}

{CODE_2}		{
	out << "<code>" << substr(yytext, 2, yyleng - 4) << "</code>";
}

{HEADING_6}		{
	out << "<h6>" + substr(yytext, 6) + "</h6>" << endl;
}

{HEADING_5}		{
	out << "<h5>" + substr(yytext, 5) + "</h5>" << endl;
}

{HEADING_4}		{
	out << "<h4>" + substr(yytext, 4) + "</h4>" << endl;
}

{HEADING_3}		{
	out << "<h3>" << substr(yytext, 3) << "</h3>" << endl;
}

{HEADING_2}		{
	out << "<h2>" << substr(yytext, 2) << "</h2>" << endl;
}

{HEADING_1}		{
	out << "<h1>" << substr(yytext, 1) << "</h1>" << endl;
}

%%

/* Sección de procedimientos */

string substr(const char* s, size_t pos, size_t len) {
	string str(s);
	return str.substr(pos, len);
}

int main(int argc, char** argv) {
	string filename_out;
	istream* p_in;
	if (argc >= 2) {
		// comprobamos si es un fichero markdown
		string filename_in(argv[1]);
		int n = filename_in.rfind('.');
		string ext = filename_in.substr(n);
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
