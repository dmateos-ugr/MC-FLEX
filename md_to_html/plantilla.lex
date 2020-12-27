%option noyywrap

/* Sección de declaraciones */
%{
#include <iostream>
#include <fstream>
#include <stack>
#include <string>
#include <algorithm>

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
// Devuelve true si ha cerrado alguna
bool end_lists(int n = 0);

// Añadir la etiqueta inicial de un header
void set_header(int n);

// Añadir la etiqueta final de un header en caso de que sea necesario
// Devuelve true si la ha añadido
bool end_headers();

// Reemplaza los caracteres de `s` que son reservados para HTML por su
// representación adecuada
void escape_html(string& s);

%}

/* Alias */
BOLD			\*\*.+\*\*
BOLD_END		\*\*
ITALIC			(\_[^\*]+\_)|(\*[^\*]+\*)
ITALIC_END		\_|\*
STRIKETHROUGH	\~\~.+\~\~
STRIKETHROUGH_END	\~\~
BLOCKQUOTE		^\>

CODE_1_LINE_CONTENT	(`{0,2}[^`])*`{0,2}
CODE_1_LINE		```{CODE_1_LINE_CONTENT}```
CODE_1 			^```.*\n(.|\n)*```\n

CODE_2_CONTENT	([^`]|"```")+
CODE_2			`{CODE_2_CONTENT}+`

PAD				" "*
LINE_1			({PAD}\-{PAD}){3,}\n
LINE_2			({PAD}\*{PAD}){3,}\n
LINE			{LINE_1}|{LINE_2}
LINK			\[.*\]\(.*\)
LINK_END		\]\(.*\)
IMAGE			\!{LINK}
UNORDERED_LIST	^\t*\-" "
ORDERED_LIST	^\t*[0-9]+\." "

HEADING			^#{1,6}

%%
 /* Sección de reglas */

\n{2,}			{
	out << endl;
	if (quote) {
		out << "</blockquote>" << endl;
		quote = false;
	}
	bool remove_br = end_headers();
	remove_br |= end_lists();
	out << endl;
	if (!remove_br)
		out << "<br><br>" << endl;
}

\n				{
	out << endl;
	if (!end_headers())
		out << "<br>" << endl;
}

{BOLD}			{
	if (bold)
		REJECT;
	out << "<b>";
	bold = true;
	yyless(2);
}

{BOLD_END}		{
	if (!bold)
		REJECT;
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
	if (!italic)
		REJECT;
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
	if (!strike)
		REJECT;
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

{CODE_1_LINE}	{
	string code = substr(yytext, 3, yyleng - 6);
	escape_html(code);
	out << "<code>" << code << "</code>";
}

{CODE_1} 		{
	string s(yytext);
	size_t start = s.find('\n') + 1;
	size_t end = s.find("\n```") + 1;
	string code = s.substr(start, end - start);
	escape_html(code);
	out << "<pre><code>" << code << "</code></pre>";
	if (end != yyleng - 3)
		yyless(start + end-start + 3);
}

{CODE_2}		{
	string code = substr(yytext, 1, yyleng - 2);
	escape_html(code);
	out << "<code>" << code << "</code>";
}

{HEADING}		{
	set_header(yyleng);
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

bool end_lists(int n) {
	bool ret = n < listas.size();
	while (n < listas.size()) {
		// Terminar listas abiertas
		out << "</li>\n</" << listas.top() << ">\n";
		listas.pop();
	}
	return ret;
}

void set_header(int n) {
	if (!header) {
		header = n;
		out << "<h" << n << ">";
	}
}

bool end_headers(){
	if (!header)
		return false;
	out << "</h" << header << ">";
	header = 0;
	return true;
}

void escape_html(string& s) {
	string buffer;
	buffer.reserve(s.size());
	for (size_t pos = 0; pos != s.size(); ++pos) {
		switch (s[pos]) {
			case '&':  buffer.append("&amp;");       break;
			case '\"': buffer.append("&quot;");      break;
			case '\'': buffer.append("&apos;");      break;
			case '<':  buffer.append("&lt;");        break;
			case '>':  buffer.append("&gt;");        break;
			default:   buffer.append(&s[pos], 1); break;
		}
	}
	s.swap(buffer);
}

void generate_html(yyFlexLexer& flujo, const string& title) {
	out <<
	  "<!DOCTYPE html>\n"
	  "<html>\n"
	  "<head>\n"
	  "<title>" << title << "</title>\n" <<
	  "<link rel=\"stylesheet\" href=\"https://stackedit.io/style.css\">"
	  "</head>\n"
	  "<body class=\"stackedit__html\">\n";

	flujo.yylex();

	out <<
	  "</p>\n"
	  "</body>\n"
	  "</html>\n";
}

void ignore_utf8_header(istream& in) {
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
