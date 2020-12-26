%option noyywrap

/* Sección de declaraciones */
%{
#include <iostream>
#include <fstream>
#include <string>

using namespace std;

int pos;
string nombre_link, link;

ifstream fichero_md;
ofstream fichero_html;
istream* in;
ostream* out;
string src, dst, fichero, html, ext = "";
int n;
%}

/* Alias */
BOLD			\*\*(.)*\*\*
ITALIC			\*(.)*\*
STRIKETHROUGH	\~\~(.)*\~\~
BLOCKQUOTE		^(\>)
CODE_1			^(```)(```)$
CODE_2			``(.)*``
LINK			\[.*\]\("http://".*\)
LINE			("* * *") | ^("---")\-* | ^("- - -")\-*

HEADING_1		^#
HEADING_2		^(#{2})
HEADING_3		^(#{3})
HEADING_4		^(#{4})
HEADING_5		^(#{5})
HEADING_6		^(#{6})

%%
 /* Sección de reglas */

{BOLD}			{
	out << "<b>" + yytext.substr(2,yytext.size()-3) + "</b>"; 
	out.flush();
} 	

{ITALIC}		{
	out << "<i>" + yytext.substr(1,yytext.size()-2) + "</i>"; 
	out.flush();
}

{STRIKETHROUGH}	{
	out << "<del>" + yytext.substr(2,yytext.size()-3) + "</del>";
	out.flush();
}

{BLOCKQUOTE}	{
	out << "<blockquote>" + yytext.substr(1) + "</blockquote>";
	out.flush();
}

{LINK}			{
	pos = yytext.rfind("http");
	nombre_link = yytext.substr(1,pos-3);
	link = yytext.substr(pos,yytext.size()-2);
	out << "<a href=\"" + link + "\">" + nombre_link + "</a>";
	out.flush();
}

{LINE}			{
	out << "<hr>" << endl;
}

{CODE_1} 		{
	out << "<code>" + yytext.substr(3,yytext.size()-4) + "</code>";
	out.flush();
}

{CODE_2}		{
	out << "<code>" + yytext.substr(2,yytext.size()-3) + "</code>";
	out.flush();
}

{HEADING_1}		{
	out << "<h1>" + yytext.substr(1) + "</h1>" << endl;
}

{HEADING_2}		{
	out << "<h2>" + yytext.substr(2) + "</h2>" << endl;
}

{HEADING_3}		{
	out << "<h3>" + yytext.substr(3) + "</h3>" << endl;
}

{HEADING_4}		{
	out << "<h4>" + yytext.substr(4) + "</h4>" << endl;
}

{HEADING_5}		{
	out << "<h5>" + yytext.substr(5) + "</h5>" << endl;
}

{HEADING_6}		{
	out << "<h6>" + yytext.substr(6) + "</h6>" << endl;
}


%%

/* Sección de procedimientos */

int main(int argc, char** argv) {
	if (argc == 2) {
		fichero = argv[1];
		n = fichero.size()-3;
		//comprobamos si es un fichero markdown
		for (int k = n; fichero.size() - k > 0; k++){
			ext += fichero[k];
    	}
		if (ext != ".md"){
			cerr << "Error. El fichero " << fichero << " no es un fichero markdown" << endl;
			exit(1);
		}
		// abrimos el fichero
		fichero_md.open(argv[1]);
		if (!fichero_md) {
			cerr << "Error abriendo fichero_md " << argv[1] << endl;
			exit(1);
		}
		in = &fichero_md;

	} else {
		in = &cin;
	}
	
	// creamos el fichero html
	html = fichero.substr(0,n);
	html += ".html";
	fichero_html.open(html);
	if (!fichero_html) {
		cerr << "Error creando el fichero " << html << endl;
		exit(1);
	}
	out = &fichero_html;

	yyFlexLexer flujo(in, out);
	flujo.yylex();
	cout << "Fin" << endl;
	fichero_md.close();
	fichero_html.close();

	return 0;
}
