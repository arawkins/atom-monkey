# Monkey Language Package


This is a direct port from the TextMate package.
It includes syntax highlighting and snippets for
core language constructs and standard libraries.

If you want to use custom snippets, it's best to put them in your custom file.
Chose the Atom Menu, then Snippets and a file will open. The syntax for snippets is like the code below:


	".source.monkey"
		"DrawCircle":
			prefix: 'DrawCircle'
			body: 'DrawCircle(${1:x}, ${2:y}, ${3:radius})$0'
		"DrawRect":
			prefix: 'DrawRect'
			body: 'DrawRect(${1:x}, ${2:y}, ${3:width}, ${4:height})$0'

For more info and how to further improve Atom for Monkey-X visit the official forums: [monkey](http://www.monkey-x.com/Community/_index_.php)

[Thread on monkey-x forums](http://www.monkey-x.com/Community/posts.php?topic=10505)
