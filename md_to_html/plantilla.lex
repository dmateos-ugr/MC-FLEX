%option noyywrap

/* Sección de declaraciones */
%{
#include <iostream>
#include <fstream>
#include <stack>
#include <string>

using namespace std;

ofstream out;
bool quote, bold, italic, strike, h, h1, h2, h3, h4, h5, h6;
stack<string> listas;

string substr(const char* s, size_t pos, size_t len = string::npos);
bool handle_list(const char* yytext, bool ordered);
%}

/* Alias */
BOLD			\*\*.+\*\*
BOLD_END		\*\*
ITALIC			\*[^\*]+\*
ITALIC_END		\*
STRIKETHROUGH	\~\~.+\~\~
STRIKETHROUGH_END	\~\~
BLOCKQUOTE		^\>
CODE_1			^```(.|\n)+```$
CODE_2			`(.)+`
LINK			\[.*\]\(.*\)
LINK_END		\]\(.*\)
UNORDERED_LIST	^\t*\-" "
ORDERED_LIST	^\t*[0-9]+\." "
LINE			("* * *")|^("---")\-*|^("- - -")\-*

HEADING_1		^#{1}
HEADING_2		^#{2}
HEADING_3		^#{3}
HEADING_4		^#{4}
HEADING_5		^#{5}
HEADING_6		^#{6}

%%
 /* Sección de reglas */

\n\n			{
	out << endl;
	if (quote) {
		out << "</blockquote>" << endl;
		quote = false;
	}
	while (!listas.empty()) {
		// Terminar listas abiertas
		out << "</li>\n</" << listas.top() << ">\n";
		listas.pop();
	}
	out << "</p>" << endl << "<p>" << endl;
}

\n				{
	if (h1)
		out << "</h1>";
	else if (h2)
		out << "</h2>";
	else if (h3)
		out << "</h3>";
	else if (h4)
		out << "</h4>";
	else if (h5)
		out << "</h5>";
	else if (h6)
		out << "</h6>";
	h = h1 = h2 = h3 = h4 = h5 = h6 = false;
	out << endl << "<br>" << endl;
}

{BOLD}			{
	if (bold)
		REJECT;
	out << "<b>";
	bold = true;
	yyless(2);
}

{BOLD_END}		{
	out << "</b>";
	bold = false;
}

{ITALIC}		{
	if (italic)
		REJECT;
	out << "<i>";
	italic = true;
	yyless(1);
}

{ITALIC_END}	{
	out << "</i>";
	italic = false;
}

{STRIKETHROUGH}	{
	if (strike)
		REJECT;
	out << "<del>";
	strike = true;
	yyless(2);
}

{STRIKETHROUGH_END}	{
	out << "</del>";
	strike = false;
}

{BLOCKQUOTE}	{
	if (!quote) {
		out << "<blockquote>";
		quote = true;
	}
}

{LINK}			{
	string s(yytext);
	int pos = s.rfind('(');
	string link = s.substr(pos+1, yyleng - (pos + 1) - 1);
	out << "<a href=\"" + link + "\">";
	yyless(1); // sólo hemos consumido el '['
}

{LINK_END}		{
	out << "</a>";
}

{LINE}			{
	out << "<hr>" << endl;
}

{CODE_1} 		{
	string s(yytext);
	int pos = s.find('\n') + 1;
	out << "<pre><code>" << s.substr(pos, yyleng - pos - 3) << "</code></pre>";
}

{CODE_2}		{
	out << "<code>" << substr(yytext, 1, yyleng - 2) << "</code>";
}

{HEADING_6}		{
	if (!h) {
		out << "<h6>";
		h = h6 = true;
	}
}

{HEADING_5}		{
	if (!h) {
		out << "<h5>";
		h = h5 = true;
	}
}

{HEADING_4}		{
	if (!h) {
		out << "<h4>";
		h = h4 = true;
	}
}

{HEADING_3}		{
	if (!h) {
		out << "<h3>";
		h = h3 = true;
	}
}

{HEADING_2}		{
	if (!h) {
		out << "<h2>";
		h = h2 = true;
	}
}

{HEADING_1}		{
	if (!h) {
		out << "<h1>";
		h = h1 = true;
	}
}

{UNORDERED_LIST}	{
	if (!handle_list(yytext, false))
		REJECT;
}

{ORDERED_LIST}		{
	if (!handle_list(yytext, true))
		REJECT;
}
%%

/* Sección de procedimientos */

string substr(const char* s, size_t pos, size_t len) {
	string str(s);
	return str.substr(pos, len);
}

bool handle_list(const char* yytext, bool ordered) {
	string l = (ordered ? "ol" : "ul");
	string s(yytext);
	int n_tabs = s.find_first_not_of('\t');
	int n_list = n_tabs + 1;
	if (n_list == listas.size() + 1) {
		// Creamos lista, posiblemente dentro de otra
		out << "<" << l << ">" << endl;
		listas.push(l);
	} else if (n_list < listas.size()) {
		// Terminamos listas, y seguimos con una lista exterior
		while (n_list < listas.size()) {
			out << "</li>\n</" << listas.top() << ">" << endl;
			listas.pop();
		}
	} else if (n_list == listas.size()) {
		// Seguimos en la misma lista. Terminar primero el elemento anterior
		out << "</li>" << endl;
	} else {
		// Lista inválida (se han añadido más de dos tabuladores nuevos).
		// Se devuelve false y se parseará como texto normal
		return false;
	}
	out << "<li>";
	return true;
}

void generate_html(yyFlexLexer& flujo, const string& title) {
	out <<
	  "<!DOCTYPE html>\n"
	  "<html>\n"
	  "<head>\n"
	  "<title>" << title << "</title>\n" <<
	  "<link rel=\"stylesheet\" href=\"https://stackedit.io/style.css\">"
	  "</head>\n"
	  "<body class=\"stackedit__html\">\n"
	  "<p>\n";

	flujo.yylex();

	out <<
	  "</p>\n"
	  "</body>\n"
	  "</html>\n";
}

int main(int argc, char** argv) {
	string filename_out, title;
	ifstream in;
	istream *p_in;
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
		title = filename_in.substr(0,n);

	} else {
		title = "out";
		p_in = &cin;
	}

	// creamos el fichero html
	filename_out = title + ".html";
	out.open(filename_out);
	if (!out) {
		cerr << "Error abriendo archivo de salida " << filename_out << endl;
		exit(1);
	}

	yyFlexLexer flujo(p_in, &out);
	generate_html(flujo, title);

	cout << "Fin" << endl;
	out.close();
	in.close();

	return 0;
}
