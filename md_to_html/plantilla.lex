%option noyywrap

/* Sección de declaraciones */
%{
#include <iostream>
#include <fstream>
#include <stack>
#include <string>

using namespace std;

ofstream out;
bool quote, bold, italic, strike;
int header;
stack<string> listas;

// Equivalente a string::substr pero para un const char*
string substr(const char* s, size_t pos, size_t len = string::npos);

// Añadir un elemento a una lista, cerrando los elementos y las listas
// anteriores en caso necesario
bool handle_list(const char* yytext, bool ordered);

// Cerrar las listas que haya abiertas hasta que solo queden `n`
void end_lists(int n = 0);

// Añadir la etiqueta inicial de un header
void set_header(int n);

// Añadir la etiqueta final de un header en caso de que sea necesario
void end_headers();
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
PAD				" "*
LINE_1			({PAD}\-{PAD}){3,}
LINE_2			({PAD}\*{PAD}){3,}
LINE			{LINE_1}|{LINE_2}
LINK			\[.*\]\(.*\)
LINK_END		\]\(.*\)
IMAGE			\!{LINK}
UNORDERED_LIST	^\t*\-" "
ORDERED_LIST	^\t*[0-9]+\." "

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
	end_headers();
	end_lists();
	out << "</p>" << endl << "<p>" << endl;
}

\n				{
	end_headers();
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

{IMAGE}			{
	string s(yytext);
	int pos = s.find("]");
	string alt = s.substr(2, pos-2);
	string link = s.substr(pos+2, yyleng - (pos + 2) - 1);
	out << "<img src=\"" << link << "\" alt=\"" << alt << "\">";
}

{LINE}			{
	end_lists();
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
	set_header(6);
}

{HEADING_5}		{
	set_header(5);
}

{HEADING_4}		{
	set_header(4);
}

{HEADING_3}		{
	set_header(3);
}

{HEADING_2}		{
	set_header(2);
}

{HEADING_1}		{
	set_header(1);
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
		end_lists(n_list);
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

void end_lists(int n) {
	while (n < listas.size()) {
		// Terminar listas abiertas
		out << "</li>\n</" << listas.top() << ">\n";
		listas.pop();
	}
}

void set_header(int n) {
	if (!header) {
		header = n;
		out << "<h" << n << ">";
	}
}

void end_headers(){
	if (!header)
		return;
	out << "</h" << header << ">";
	header = 0;
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

void ignore_utf8_header(istream& in) {
	//unsigned char header[] = "\xEF\xBB\xBF";
	int header[] = {0xEF, 0xBB, 0xBF};
	for (int i = 0; i < sizeof(header)/sizeof(header[0]); i++) {
		if (in.peek() != header[i])
			return;
		in.ignore();
	}
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

	ignore_utf8_header(*p_in);
	yyFlexLexer flujo(p_in, &out);
	generate_html(flujo, title);

	cout << "Fin" << endl;
	out.close();
	in.close();

	return 0;
}
