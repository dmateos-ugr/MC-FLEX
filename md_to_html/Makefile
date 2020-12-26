all: prog

prog: lex.yy.cc
	g++ lex.yy.cc -o prog

lex.yy.cc: plantilla.lex
	flex --c++ plantilla.lex

clean:
	rm prog
	rm lex.yy.cc
	rm *.html
