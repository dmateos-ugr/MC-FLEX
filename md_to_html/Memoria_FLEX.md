﻿# PASO DE MARKDOWN A HTML
---
- **Becerra Burgos, Alejandro**
- **Mateos Romero, David**
---
## ÍNDICE
1. **Introducción**
2. **Desarrollo de la aplicación**
    - **Planteamiento**
    - **Plantilla**
        - **Sección de Declaraciones**
        - **Sección de Reglas**
        - **Sección de Procedimientos de Usuario**
    - **Generación del código fuente**
3. **Ejemplo de ejecución**
4. **Reflexiones**


## 1. INTRODUCCIÓN
Markdown es un lenguaje de marcado que facilita la aplicación de formato a un texto empleando una serie de caracteres de una forma especial. Por otro lado, HTML es un lenguaje de marcado que se utiliza para el desarrollo de páginas de Internet. En esta memoria se explicará con completo detalle el desarrollo de una aplicación que convierte archivos Markdown (extensión _.md_) en archivos HTML.

La aplicación ha sido creada en lenguaje C++ mediante el uso del generador de analizadores léxicos _flex_. _flex_ se apoya en una plantilla que recibe como parámetro y, a partir de ella, genera el código fuente. La estructura de la plantilla se compone de tres secciones: sección de Declaraciones, sección de Reglas y sección de Procedimientos de Usuario.


## 2. DESARROLLO DE LA APLICACIÓN
## - Planteamiento
En primer lugar, tenemos que tener claro el funcionamiento que presentará la aplicación a desarrollar. Queremos que la aplicación reciba un archivo Markdown y que, a partir de este, genere un archivo equivalente en formato HTML. Las funcionalidades del lenguaje Markdown que vamos a implementar son, entre otras, marcado en negrita, cursiva, tachado, citas, códigos, links y títulos.

Todo el desarrollo de la aplicación recae sobre la creación de la plantilla sobre la cual se apoyará *flex* para generar el código fuente.

## - Plantilla

Como la aplicación solo recibirá un fichero de entrada, podemos omitir la llamada a yywrap() con la opción noyywrap, obteniendo así una mejora de eficiencia. Para el desarrollo de está aplicación será necesario la implementación de las tres secciones de una estructura de plantilla *flex*, las cuales se detallan a continuación.

### Sección de Declaraciones
- **Bloque de copia**

En este bloque le indicaremos al pre-procesador que lo que estamos definiendo queremos que aparezca “tal cual” en el fichero C++ generado.

Es un bloque delimitado por las secuencias %{ y %} donde podemos indicar la inclusión de los ficheros de cabecera necesarios, la declaración de variables globales y las declaraciones de procedimientos descritos en la sección de Procedimientos de Usuario.

En este bloque necesitaremos incluir:
- Ficheros de cabecera: `iostream, fstream, string, stack`
- Variables globales:
    - `ofstream out`- Será nuestro flujo de salida para la escritura del fichero HTML.
    - `bool quote, bold, italic, strike` - Una variable global booleana para algunas funcionalidades de markdown que pueden ser anidadas y que requieren trato especial. Hablaremos más a fondo de este trato en la sección de Reglas.
    - `int header`- Indicará el tipo de título que hay abierto en ese instante, para luego cerrarlo.
    - `stack<string> listas` - Si hay listas anidadas necesitamos saber en qué orden cerrarlas.
- Procedimientos:
    - `string substr(const  char* s, size_t pos, size_t len = string::npos)`
    Procedimiento que usaremos para obtener subcadenas de _yytext_.
    - `bool  handle_list(const  char* yytext, bool ordered)`
    Procedimiento que usaremos para añadir un elemento a una lista, cerrando los elementos y las listas anteriores en caso necesario.
    - `bool  end_lists(int n =  0)`
    Cierra las listas que haya abiertas hasta que solo queden _n_.
    - `void  set_header(int n)`
    Añade la etiqueta inicial de un título.
    - `bool  end_headers()`
    Añadir la etiqueta final de un título en caso de que sea necesario.
    - `void  escape_html(string& s)`
    Reemplaza los caracteres de _s_ que son reservados para HTML por su representación adecuada.

Por tanto, el bloque de copia nos quedaría de la siguiente forma:
```C++
%{
#include  <iostream>
#include  <fstream>
#include  <stack>
#include  <string>

using  namespace std;

ofstream out;
bool quote, bold, italic, strike;
int header;
stack<string> listas;

string  substr(const  char* s, size_t pos, size_t len = string::npos);
bool  handle_list(const  char* yytext, bool ordered);
bool  end_lists(int n =  0);
void  set_header(int n);
bool  end_headers();
void  escape_html(string& s);
%}
```

- **Bloque de definición de alias**

En este bloque definiremos las expresiones regulares necesarias para identificar las distintas funcionalidades de Markdown que queremos implementar.

Es necesario que al principio de cada línea aparezca el nombre con el cual queremos identificar la expresión regular, seguido de la propia expresión regular con **al menos** una tabulación.

En este bloque incluimos:
- `BOLD \*\*.+\*\*`  y `BOLD_END \*\*` para poder identificar las cadenas en **negrita**: una sucesión de caracteres delimitada por dos asteriscos antes y después.
- `ITALIC (\_[^\*]+\_)|(\*[^\*]+\*)` y `ITALIC_END \_|\*` para poder identificar las cadenas en *cursiva*: una sucesión de caracteres delimitada por un asterisco antes y después.
- `STRIKETHROUGH \~\~.+\~\~` y `STRIKETHROUGH_END \~\~` para poder identificar las cadenas ~~tachadas~~: una sucesión de caracteres delimitada por dos virgulillas antes y después.
- `BLOCKQUOTE ^\>` para poder identificar las citas, que comienzan con un signo "mayor que", y se extienden hasta que se encuentren dos saltos de línea.
> Ejemplo de cita
- `LINK \[.*\]\(.*\)` y `LINK_END \]\(.*\)` para identificar los [links](https://stackedit.io/): sucesión de caracteres delimitada por corchetes (texto) seguida de sucesión de caracteres delimitada por paréntesis (enlace).
- `PAD " "*` para identificar espacios en blanco.
- `LINE_1 ({PAD}\-{PAD}){3,}\n` y `LINE_2 ({PAD}\*{PAD}){3,}\n` para poder identificar las líneas: sucesiones de mínimo tres guiones o asteriscos con posibles espacios en medio. Ejemplo:
- --
- `LINE {LINE_1}|{LINE_2}` para identificar los dos tipos de línea descritos anteriormente (guiones o asteriscos).
- `HEADING ^#{1,6}` para poder identificar los distintos tipos de títulos, que comienzan con una sucesión de como mucho seis almohadillas, y terminan con un salto de línea.
- `IMAGE \!{LINK}` para poder identificar las imágenes, que son iguales que los enlaces pero con una exclamación al inicio.
- `UNORDERED_LIST ^\t*\-" "` para poder identificar las listas no enumeradas: sucesión de tabuladores posiblemente nula para los casos de listas anidadas seguida de un guión y un espacio.
- `ORDERED_LIST ^\t*[0-9]+\." "` para poder identificar las listas enumeradas: idénticas a las no enumeradas pero con un número en vez de un guión. Markdown ignora ese número y simplementa numera en orden ascendente.
- Para la identificación de código incluimos 5 expresiones regulares distintas debido a la gran diversidad presentada por Markdown en este ámbito, así como su complejidad de implementación.
```
CODE_1_LINE_CONTENT         (`{0,2}[^`])*`{0,2}
CODE_1_LINE                 ```{CODE_1_LINE_CONTENT}```
CODE_1                      ^```.*\n(.|\n)*```\n

CODE_2_CONTENT              ([^`]|"```")+
CODE_2                      `{CODE_2_CONTENT}+`
```
- `CODE_1` -> Para identificar los códigos en forma de bloque: una sucesión de líneas delimitada por tres comillas inversas seguidas de un salto de línea al inicio y al final.
- `CODE_1_LINE`-> Para identificar los códigos en línea de 3 comillas inversas: el contenido delimitado por tres comillas inversas al inicio y al final.
- `CODE_1_LINE_CONTENT` -> Contenido de los cógidos en línea de 3 comillas inversas: sucesión de caracteres que no incluye 3 comillas inversas seguidas. Expresión regular obtenida a partir siguiente autómata, donde 'x' se refiere a la comilla inversa y 'c' a cualquier otro caracter

![automata](https://i.imgur.com/CW6hyS0.png)
- `CODE_2`-> Para identificar los códigos en línea de 1 comilla inversa: contenido delimitado por una comilla inversa al inicio y al final.
- `CODE_2_CONTENT` -> Contenido de los códigos en línea de 1 comilla inversa: sucesión de caracteres que no puede incluir comillas inversas excepto si son 3 seguidas.

Las expresiones regulares *FUNCIONALIDAD*_END son necesarias para cubrir el problema de anidamiento de funcionalidades. En la sección de Reglas se mostrará más a fondo el motivo de su necesidad.

Finalmente, el bloque de alias nos quedaría de la siguiente forma:

```
BOLD                        \*\*.+\*\*
BOLD_END                    \*\*
ITALIC                      (\_[^\*]+\_)|(\*[^\*]+\*)
ITALIC_END                  \_|\*
STRIKETHROUGH               \~\~.+\~\~
STRIKETHROUGH_END           \~\~
BLOCKQUOTE                  ^\>

CODE_1_LINE_CONTENT         (`{0,2}[^`])*`{0,2}
CODE_1_LINE                 ```{CODE_1_LINE_CONTENT}```
CODE_1                      ^```.*\n(.|\n)*```\n

CODE_2_CONTENT              ([^`]|"```")+
CODE_2                      `{CODE_2_CONTENT}+`

PAD                         " "*
LINE_1                      ({PAD}\-{PAD}){3,}\n
LINE_2                      ({PAD}\*{PAD}){3,}\n
LINE                        {LINE_1}|{LINE_2}
LINK                        \[.*\]\(.*\)
LINK_END                    \]\(.*\)
IMAGE                       \!{LINK}
UNORDERED_LIST              ^\t*\-" "
ORDERED_LIST                ^\t*[0-9]+\." "

HEADING                     ^#{1,6}
```



### Sección de Reglas
Esta es la sección más importante en el proceso de desarrollo de la aplicación. En ella, vamos a indicar las acciones que queremos realizar cuando se identifique una de las funcionalidades descritas en la sección anterior, es decir, qué queremos que haga nuestro programa cuando se lea del fichero de entrada una cadena que cumpla una determinada expresión regular. En resumen, es donde vamos a describir el paso a fichero de tipo HTML.

En esta sección sólo se permite un tipo de escritura. Las reglas se definen como sigue:
```
Expresión_Regular		 {acciones escritas en C++}
```
Al comienzo de la línea se indica la expresión regular, seguida inmediatamente por **uno o varios** tabuladores, hasta llegar al conjunto de acciones en C++ que deben ir encerrados en un bloque de llaves.

Es importante destacar que _flex_ sigue las siguientes normas para la identificación de expresiones regulares:
- Siempre intenta encajar una expresión regular con la cadena más larga posible.
- En caso de conflicto entre expresiones regulares (pueden aplicarse dos o más para una misma cadena de entrada), _flex_ se guía por estricto orden de declaración de las reglas.

Existe una regla por defecto, que es: `. {ECHO;}`.  Esta regla se aplica en el caso de que la entrada no encaje con ninguna de las reglas. Lo que hace es imprimir en la salida (en nuestro caso el archivo HTML creado) el carácter que no encaja con ninguna regla.

Veamos las reglas que incluimos.

#### Funcionalidad de **negrita**

En primer lugar, tenemos que consultar como se colorean las palabras en negritas en el formato HTML. Esto es, usando la etiqueta `<b>` ó `<strong>`. Nosotros solo haremos uso de la etiqueta `<b>`.

Para implementar esta funcionalidad vamos a crear dos reglas, una para comenzar la escritura en negrita `BOLD` y otra para terminar la escritura en negrita `BOLD_END`.

Necesitamos implementar la funcionalidad de esta forma ya que, como se mencionaba en la sección anterior, tenemos que tener en cuenta posibles anidamientos entre distintas funcionalidades. No podemos hacer únicamente una regla para `BOLD` que escriba directamente cualquier cadena de la forma `**cadena**` en negrita, ya que en este caso la palabra **_cadena_**, es decir, `**_cadena_**` ó `***cadena***` se traduciría al fichero HTML como `<b>_cadena_<\b>` ó `<b>*cadena*<\b>`, cuando la traducción correcta sería `<b><i>cadena<\i><\b>`. Esto es solo un ejemplo, este mismo caso se puede trasladar al anidamiento con cualquier otra funcionalidad.

Por otra parte, tampoco podemos tener una sola regla `**` que cambie una variable booleana y que abra o cierre la etiqueta dependiendo de esta, ya que ** es una cadena válida (como se puede observar) que no debería interpretarse como negrita.

_flex_ siempre va a aplicar la funcionalidad externa en caso de funciones anidadas, pues como se ha explicado anteriormente, _flex_ prioriza la cadena más larga posible a la que le puede aplicar una regla.

Por tanto, las reglas nos quedarían de la siguiente forma:
- Regla para la expresión regular `BOLD`
```C++
{BOLD} {
    if (bold)
        REJECT;
    out <<  "<b>";
    bold =  true;
    yyless(2);
}
```
En primer lugar, si la palabra ya se está escribiendo en negrita, ignoramos la regla. Si la palabra no se estaba escribiendo en negrita, introducimos la etiqueta `<b>`, indicamos que se está escribiendo en negrita y que solo hemos procesado los dos primeros caracteres de la cadena (`**`), para que el resto se vuelva a evaluar, dejando paso así a las funcionalidades anidadas.

- Regla para la expresión regular `BOLD_END`
```C++
{BOLD_END} {
    if (!bold)
        REJECT;
    out <<  "</b>";
    bold =  false;
}
```
No se parsea en caso de no estar escribiendo en negrita. En caso contrario, se cierra la etiqueta y se indica que se ha dejado de escribir en negrita.

#### Funcionalidad de *cursiva*
Siendo la etiqueta `<i>` utilizada en el formato HTML para la escritura en cursiva, vamos a proceder análogamente al caso anterior.
- Regla para la expresión regular `ITALIC`
```C++
{ITALIC} {
    if (italic)
        REJECT;
    out <<  "<i>";
    italic =  true;
    yyless(1);
}
```
- Regla para la expresión regular `ITALIC_END`
```C++
{ITALIC_END} {
    if (!italic)
        REJECT;
    out <<  "</i>";
    italic =  false;
}
```

#### Funcionalidad de ~~tachado~~
Siendo la etiqueta `<del>` utilizada en el formato HTML para la escritura en tachado, vamos a proceder análogamente a los casos anteriores.
- Regla para la expresión regular `STRIKETHROUGH`
```C++
{STRIKETHROUGH}	{
    if (strike)
        REJECT;
    out << "<del>";
    strike = true;
    yyless(2);
}
```
- Regla para la expresión regular `STRIKETHROUGH_END`
```C++
    if (!strike)
        REJECT;
    out << "</del>";
    strike = false;
```

#### Funcionalidad de cita
La etiqueta `<blockquote>` es utilizada en el formato HTML para la escritura de citas.

En este caso, solo necesitaremos implementar una regla para la expresión regular `BLOCKQUOTE` que se encargará de iniciar una cita. La finalización de una cita se dará con dos o más saltos de líneas consecutivos, regla la cual implementaremos posteriormente.
```C++
{BLOCKQUOTE}	{
    if (!quote) {
        out << "<blockquote>";
        quote = true;
    }
}
```
En caso de que no se esté escribiendo ya una cita, se inicia e indica su escritura.
#### Funcionalidad de link
En formato HTML el link viene definido por la etiqueta `<a>` bajo la sintaxis `<a href="url">link text</a>`.

Implementaremos dos reglas, una para la expresión regular `LINK` que se encargará de almacenar el link e iniciar la escritura del nombre, y otra para la expresión regular `LINK_END` que se encargará de finalizar la escritura del nombre del link.

- Regla para la expresión regular `LINK`
```C++
{LINK}			{
    string s(yytext);
    int pos = s.rfind('(');
    string link = s.substr(pos+1, yyleng - (pos + 1) - 1);
    out << "<a href=\"" + link + "\">";
    yyless(1);
}
```
Escribimos el link e indicamos que tan solo hemos procesado el carácter `[` para que se procese el nombre del link y pueda aceptar otras funcionalidades.

- Regla para la expresión regular `LINK_END`
```C++
{LINK_END}		{
    out << "</a>";
}
```
Terminamos la escritura del nombre del link y, con ello, la escritura completa del link.

#### Funcionalidad de insertado de imágenes
La etiqueta `<img>` es usada en formato HTML para el insertado de imágenes. Realmente no se inserta la imagen, sino que se enlaza a la página web. Es un caso especial ya que no tiene etiqueta de cerrado y requiere dos atirbutos:
- src: especifica el enlace a la imagen.
- alt: especifica un texto alternativo para la imagen.

En este caso, una única regla va a inciar y terminar la funcionalidad. Su implementación quedaría de la siguiente forma:
```C++
{IMAGE}			{
    string s(yytext);
    int pos = s.find("]");
    string alt = s.substr(2, pos-2);
    string link = s.substr(pos+2, yyleng - (pos + 2) - 1);
    out << "<img src=\"" << link << "\" alt=\"" << alt << "\">";
}
```
Leemos el link y el texto alternativo. A continuación, escribimos la etiqueta completa.
#### Funcionalidad para el insertado de líneas horizontales
En formato HTML se usa la etiqueta `<hr>` para el insertado de líneas horizontales. Es una etiqueta que, al igual de la etiqueta `<img>`, prescinde de etiqueta de cerrado.

Como ya vimos en el bloque de alias, contamos con una expresión regular `LINE` que nos va a facilitar la implementación de esta funcionalidad. Tendremos que implementar una única regla que se encargará del insertado de línea, la cual se muestra a continuación:
```C++
{LINE}			{
    end_lists();
    out << "<hr>" << endl;
}
```
Como se puede observar, es una funcionalidad muy sencilla de implementar. Lo único que tenemos que tener en cuenta es, que en caso de estar dentro de un conjunto de listas, tendremos que finalizarlas.
#### Funcionalidad para el insertado de títulos
Los títulos en HTML se definen con las etiquetas `<h1>` hasta `<h6>`, siendo `<h1>` el título más importante y `<h6>`el de menor relevancia y, por tanto, menor tamaño.

Para la implementación de esta funcionalidad nos apoyaremos sobre el procedimiento `set_header(int)` ya mencionado en la sección de Declaraciones y el cual trataremos con más detalle en la sección de Procedimientos de Usuario.

La finalización de escritura de un título se dará con uno o más saltos de líneas consecutivos, regla la cual implementaremos posteriormente.
```C++
{HEADING}		{
    set_header(yyleng);
}
```
#### Funcionalidad para el uso de listas
Para la implementación de esta funcionalidad nos apoyaremos sobre el procedimiento `handle_list(const char* yytext, bool ordered)` ya mencionado en la sección de Declaraciones y el cual trataremos con más detalle en la sección de Procedimientos de Usuario.

Los elementos de una lista en HTML se representan mediante la etiqueta `<li>`. Sin embargo, la representación de la lista varía según si es ordenada o no.
- Listas sin orden
Las listas sin orden en HTML se representan mediante la etiqueta `<ul>`. Su implementación vendrá dada por la siguiente regla:
```C++
{UNORDERED_LIST}	{
    if (!handle_list(yytext, false))
        REJECT;
}
```

- Listas enumeradas
Las listas ordenadas en HTML se representan mediante la etiqueta `<ol>`. Su implementación vendrá dada por la siguiente regla:
```C++
{ORDERED_LIST}		{
    if (!handle_list(yytext, true))
        REJECT;
}
```

En ambos casos, intentamos añadir un elemento a la lista. Si ese elemento no es válido, no se parsea. La finalización de una lista se dará con dos o más saltos de líneas consecutivos, regla la cual implementaremos posteriormente.
#### Funcionalidad para el insertado de código
En HTML el mostrado de código se representa mediante la etiqueta `<code>`.

La implementación de esta funcionalidad es bastante compleja ya que tenemos que tener en cuenta todas las posibles formas de representar código en formato Markdown y tener cuidado con todas las excepciones que presenta. Es por ello que vamos a necesitar implementar una regla por cada modelo de representación existente en Mardown. A su vez, cabe destacar que en todas ellas nos apoyaremos sobre el procedimiento `escape_html(string& s)` ya mencionado en la sección de Declaraciones y el cual trataremos con más detalle en la sección de Procedimientos de Usuario. Incluimos así las siguientes reglas:
- Para una línea de código representada entre 3 comillas inversas en Mardown
``` C++
{CODE_1_LINE}	{
    string code = substr(yytext, 3, yyleng - 6);
    escape_html(code);
    out << "<code>" << code << "</code>";
}
```
Leemos el código, cambiamos los caracteres reservados de HTML y escribimos la etiqueta con el código.

- Para un bloque de código
```C++
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
```
En nuestra aplicación vamos a prescindir del coloreado del código según el lenguaje utilizado, luego omitimos la cadena que representa el tipo de lenguaje. Leemos el código delimitado por los saltos de línea después de las 3 primeras comillas inversas hasta encontrar otras 3 comillas inversas. A continuación, escribimos la etiqueta con dicho código leído en el fichero HTML. Posteriormente, como _flex_ escoge la expresión regular más grande, puede que dentro de este bloque de código haya varios más, por ello es necesario hacer una delimitación manual e indicarle a flex que en ese caso siga procesando el resto.

- Para una línea de código representada entre simples comillas inversas en Mardown
```C++
{CODE_2}		{
    string code = substr(yytext, 1, yyleng - 2);
    escape_html(code);
    out << "<code>" << code << "</code>";
}
```
Análogo a la regla `CODE_1_LINE`.

#### Saltos de línea
Los saltos de línea van a determinar la finalización de escritura de títulos, citas y listas.
- Un salto de línea
```C++
\n				{
    out << endl;
    if (!end_headers())
        out << "<br>" << endl;
}
```
Escribimos en el fichero HTML un salto de línea. Si se estaba escribiendo un título se finaliza su escritura. En caso contrario, introducimos una etiqueta _line break_.

- Dos o más saltos de línea consecutivos
```C++
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
```
Escribimos dos saltos de línea. Se finalizan las escrituras de citas, títulos y listas. Si no se estaba escribiendo ningún título ó lista tenemos que introducir dos etiquetas _line break_.


### Sección de Procedimientos de Usuario
En esta sección escribiremos en C++ sin ninguna restricción aquellos procedimientos que hayamos necesitado en la sección de Reglas. Todo lo que aparezca en esta sección será incorporado al final del fichero fuente generado.

Necesitamos incluir:
- La implementación del método `string substr(const char* s, size_t pos, size_t len)`

Creamos un string a partir del puntero constante char y usamos el método de instancia substr de la clase string de la STL.
```C++
string substr(const char* s, size_t pos, size_t len) {
    string str(s);
    return str.substr(pos, len);
}
```
- La implementación del método `bool handle_list(const  char* yytext, bool ordered)`

```C++
bool handle_list(const  char* yytext, bool ordered) {
    string l = (ordered ?  "ol"  :  "ul");
    string s(yytext);
    int n_tabs =  s.find_first_not_of('\t');
    int n_list = n_tabs +  1;

    if (n_list ==  listas.size() +  1) {
        // Creamos lista, posiblemente dentro de otra
        out <<  "<"  << l <<  ">"  << endl;
        listas.push(l);
    } else  if (n_list <  listas.size()) {
        // Terminamos listas, y seguimos con una lista exterior
        end_lists(n_list);
    } else  if (n_list ==  listas.size()) {
        // Seguimos en la misma lista. Terminar primero el elemento anterior
        out <<  "</li>"  << endl;
    } else {
        // Lista inválida (se han añadido más de dos tabuladores nuevos).
        // Se devuelve false y se parseará como texto normal
        return  false;
    }
    out <<  "<li>";

    return  true;
}
```
- La implementación del método `void  end_lists(int n)`

Mediante un while vamos a ir quitando listas de la pila hasta que haya _n_ listas en ella. Antes de sacar la lista de la pila, finalizamos la lista en el fichero HTML.

```C++
void end_lists(int n) {
    while (n <  listas.size()) {
        // Terminar listas abiertas
        out <<  "</li>\n</"  <<  listas.top() <<  ">\n";
        listas.pop();
    }
}
```
- La implementación del método `void  set_header(int n)`

Si no se está escribiendo un título, se va a escribir en el fichero HTML el inicio de título con el tipo indicado por parámetro

```C++
void set_header(int n) {
    if (!header) {
        header = n;
        out <<  "<h"  << n <<  ">";
    }
}
```
- La implementación del método `void  end_headers()`

En caso de estar escribiéndose un título se va a escribir en el fichero HTML un fin de título correspondiente. Dejamos la variable global _header_ a 0 para indicar que no se está escribiendo ningún título.
```C++
void end_headers(){
    if (!header)
        return;
    out <<  "</h"  << header <<  ">";
    header =  0;
}
```
- La implementación del método `escape_html(string& s)`

Mediante el uso de un for vamos a recorrer todos los caracteres de una cadena y, con la ayuda de un switch, los cambiamos por su representación adecuada en caso de ser un símbolo reservado para HTML.
```C++
void escape_html(string& s) {
    string buffer;
    buffer.reserve(s.size());

    for (size_t pos =  0; pos !=  s.size(); ++pos) {
        switch (s[pos]) {
            case  '&': buffer.append("&amp;"); break;
            case  '\"': buffer.append("&quot;"); break;
            case  '\'': buffer.append("&apos;"); break;
            case  '<': buffer.append("&lt;"); break;
            case  '>': buffer.append("&gt;"); break;
            default: buffer.append(&s[pos], 1); break;
        }
    }
    s.swap(buffer);
}
```
- Un método para generar la cabecera del fichero HTML

Escribimos la cabecera del fichero HTML antes de llamar a la función _yylex()_.
```C++
void generate_html(yyFlexLexer& flujo, const  string& title) {
    out <<
        "<!DOCTYPE html>\n"
        "<html>\n"
        "<head>\n"
        "<title>"  << title <<  "</title>\n"  <<
        "<link rel=\"stylesheet\" 	href=\"https://stackedit.io/style.css\">"
        "</head>\n"
        "<body class=\"stackedit__html\">\n"
        "<p>\n";

    flujo.yylex();

    out <<
        "</p>\n"
        "</body>\n"
        "</html>\n";
}
```
- La función main

En primer lugar comprobaremos si se está pasando un fichero como argumento. Tenemos así dos situaciones:

_1_ - Nos proporcionan un fichero.


En este caso tenemos que comprobar que el fichero sea de tipo Markdown, es decir, extensión _.md_. Si el tipo de fichero no es válido, se aborta la ejecución del programa con un error.
```C++
    if (argc >= 2) {
        // comprobamos si es un fichero markdown
        string filename_in(argv[1]);
        int n = filename_in.rfind('.');
        string ext = filename_in.substr(n);
        if (ext != ".md"){
            cerr << "Error. El fichero " << filename_in << " no es un fichero markdown" << endl;
            exit(1);
        }
```
En caso contrario, el fichero se abre y se guarda su nombre para utilizarlo en la creación del fichero HTML.
```C++
        // abrimos el fichero
        in.open(argv[1]);
        if (!in) {
            cerr << "Error abriendo archivo de entrada " << argv[1] << endl;
            exit(1);
        }
        p_in = &in;
        title = filename_in.substr(0,n);
```


_2_ - El programa se ejecuta sin argumentos


En este caso, permitimos que se escriba en Markdown por la entrada estándar, es decir, directamente por teclado, y asignamos un nombre por defecto para el fichero HTML.

```C++
    } else {
        title = "out";
        p_in = &cin;
    }
```

 Una vez ya establecido el flujo de entrada y el nombre para nuestro fichero HTML, procedemos a la creación del mismo:
```C++
    // creamos el fichero html
    filename_out = title + ".html";
    out.open(filename_out);
    if (!out) {
        cerr << "Error abriendo archivo de salida " << filename_out << endl;
        exit(1);
    }
```
Antes de la lectura del fichero, ignoramos una posible marca de orden de bytes.
```C++
    ignore_utf8_header(*p_in);
```

Finalmente, iniciamos la lectura de la entrada y la escritura del fichero HTML.
```C++
    yyFlexLexer flujo(p_in, &out);
    generate_html(flujo, title);
```

La función main completa quedaría por tanto de la siguiente manera:

```C++
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
```

## - Generación del código fuente
Para generar el código fuente tendremos que ejecutar la siguiente orden:
```
flex --c++ plantilla.lex
```
Obteniendo así el archivo `lex.yy.cc`. A partir de éste podemos obtener el ejecutable con la orden:
```
g++ lex.yy.cc -o prog
```
Para hacer el proceso de generación del ejecutable más rápido y sencillo podemos crear el siguiente makefile:
```
all: prog

prog: lex.yy.cc
    g++ lex.yy.cc -o prog

lex.yy.cc: plantilla.lex
    flex --c++ plantilla.lex
clean:
    rm prog
    rm lex.yy.cc
    rm *.html
```

## 3. Ejemplo de ejecución
Esta memoria se ha realizado en Markdown. Como ejemplo de ejecución se propone al lector hacer uso de la aplicación para pasarla a formato HTML. Para agilizar dicha ejecución se puede hacer uso del siguiente script:
```
#script run.sh

set -e
make
./prog Memoria_FLEX.md
```
Entre los archivos proporcionados puede encontrar el resultado en HTML de esta operación. Debería ser prácticamente idéntico al PDF original, excepto por la ausencia de color en los trozos de código.

## 4. Reflexiones
En esta práctica hemos aprendido a usar flex, y a pesar de sólo conocer sus funcionalidades más básicas, hemos podido construir una aplicación relativamente compleja para exportar código Markdown a HTML. De esta forma le dotamos de un estilo específico y de capacidad para ser guardado en otros formatos más universales, como puede ser PDF.

Hemos tenido algunas dificultades, siendo la mayor de ellas la ausencia de un estándar común para Markdown y las consecuentes diferencias entre los distintos motores existentes que intentan llevar a cabo la tarea descrita. Hemos sufrido particularmente con las variadas formas de mostrar código en Markdown (comillas inversas).

Sin embargo, al tener esta memoria como ejemplo de fichero Markdown que explota al máximo sus funcionalidades, creemos haber conseguido la correctitud de nuestros procedimientos.