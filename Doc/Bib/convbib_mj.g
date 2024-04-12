##  
#A  convbib.g                                                Frank Lübeck
##  
##  A conversion tool to produce from the bib-files an html version and a
##  pdf-version for the web-pages, using GAPDoc.
##  
##  Add handling of further  bib-files at the end.
##  
LoadPackage("GAPDoc");

Read("MSC2020.g");

StatisticsByMSC:=function()
  local ourbib, duplicates, q, w, tab, msccodes, mscnames, 
        b, nr, pos, posnomsc, prim, sec, i, total;
  Print( "Reading the GAP bibliography ... \n" );
  ourbib:=ParseBibFiles("gap-published.bib")[1];;
  Print( "Checking for multiple labels ... \n");
  duplicates := Filtered( Collected( List( ourbib, q->q.Label) ), w -> w[2]>1 );
  if Length(duplicates) > 0 then
    Print("The following labels are defined more than once ", 
          List( duplicates, w -> w[1] ), "\n");
  fi;
  Print( "Loaded ", Length(ourbib), " records from GAP bibliography\n");
  tab:=[];
  msccodes:=List(MSC2020, w -> w[1]);
  mscnames:=List(MSC2020, w -> w[2]);
  SortParallel( msccodes, mscnames);
  posnomsc := Position( msccodes, "XX" );
  for i in [1..Length(msccodes)] do
    tab[i] := [ 0, 0, msccodes[i], mscnames[i] ];
  od;
  for b in ourbib do
    if IsBound(b.mrclass) then
      nr := b.mrclass;
      prim := nr{[1..2]};
      pos := Position( msccodes, prim ); 
      if pos <> fail then
        tab[pos][1]:=tab[pos][1]+1;
        pos := PositionSublist( nr, " (" );
        if pos <> fail then
          sec := SplitString( nr{[pos+2..Length(nr)]}, " ", " )");
          sec := Set( List( sec, q -> q{[1..2]} ) );
          for q in sec do 
            if q <> prim then
              pos := Position( msccodes, q ); 
              tab[pos][2]:=tab[pos][2]+1;
            fi;
          od;
        fi;  
      else  
        tab[posnomsc][1]:=tab[posnomsc][1]+1;
      fi;
    else
      tab[posnomsc][1]:=tab[posnomsc][1]+1;
    fi;  
  od;
  tab[posnomsc][2]:="";
  tab[posnomsc][3]:="XX";
  tab := Filtered( tab, w -> w[1]+w[2]>0 );
  total := [ Sum( List( tab, w -> w[1] ) ), "", "TOTAL", "TOTAL" ];
  Add( tab, total );
  return tab;
end;

string_for_sorting := function(str)
    str := SIMPLE_STRING(LowerASCIIString(str));
    RemoveCharacters(str, "{}");
    return str;
end;

bib2niceandhtml := function(name, header, subheader)
  local i, ii, bib, fh, out, a, b, years, counts, pos, flag, 
        mscreport, bstr, str, bad, citations_by_year_outfile,
        citations_by_msc_outfile;
  years:=[1987..2023];
  bstr := StringFile(Concatenation(name, ".bib"));
  bstr := HeuristicTranslationsLaTeX2XML.Apply(bstr);
  bib := ParseBibStrings(StringFile("gap-head.bib"), bstr);
  counts:=List(years,i->0);
  for a in bib[1] do 
    NormalizeNameAndKey(a);
    pos:=Position(years,Int(a.year));
    if pos<>fail then
      counts[pos]:=counts[pos]+1;
    elif Length(a.year)=7 and a.year[5]='/' then
      # year in format "2001/02"?
      pos:=Position(years,Int(a.year{[1,2,6,7]}));
      if pos<>fail then
        Print( a.Label, " : ", a.year, " --> ", a.year{[1,2,6,7]}, "\n" );
        counts[pos]:=counts[pos]+1;
      else
        Print("Warning: unrecognised year in ", a.Label, "\n");
      fi;
    else
      Print("Warning: no year is given in ", a.Label, "\n");
    fi;
    Unbind(a.authororig); Unbind(a.editororig); Unbind(a.keylong);
  od;
  StableSortBy(bib[1], a -> [string_for_sorting(a.author), a.year, string_for_sorting(a.title)]);
  Print("Sorted ", Length(bib[1]), " records \n");
  WriteBibFile(Concatenation(name, "nicer.bib"),[bib[1],[],[]]);
  # now we produce a temporary version were we substitute back
  # some unicode characters currently not handled by pdflatex
  bad := [["ʹ","{\\cprime}"], ["ą","{\\k a}"],["Ð","{\\Dbar}"],
          ["Ṗ","\.{P}"], ["ọ","\d{o}"] ];
  str := StringFile(Concatenation(name, "nicer.bib"));
  for a in bad do
    str := SubstitutionSublist(str, a[1], a[2]);
  od;
  FileString(Concatenation(name, "nicertmp.bib"), str);
  fh := function() 
    local a, str, strxml, strrec; 
    Print("<html>\n<head>\n",
    "<meta http-equiv=\"Content-Type\" content=\"text/html;", 
    " charset=utf-8\">\n\n",
    "<script type=\"text/javascript\"\n",
    "src=\"https://cdn.jsdelivr.net/npm/mathjax@2/MathJax.js?config=TeX-AMS-MML_HTMLorMML\">\n",
    "</script>\n</head>\n",
    "<body bgcolor=\"#FFFFFF\">\n<br>\n<h1 align=\"center\">",
    header,
    "</h1>",
    subheader,
    "\n\n");
    for a in bib[1] do 
      strxml := StringBibAsXMLext(a, "UTF-8");
      # some entries are not valid BibTeX
      if strxml = fail then
        # fallback
        b := ShallowCopy(a);
        b.title:=Filtered(b.title,x-> not x in "{}");
        PrintBibAsHTML(b); 
      else
        strrec := ParseBibXMLextString(strxml);
        str := StringBibXMLEntry(strrec.entries[1], "HTML", 
                                 strrec.strings, rec(MathJax := true));
        Print(str,"\n");
      fi;
      Print("<pre>\n");
      str := StringBibAsBib(a);
      # escape HTML chars
      str := SubstitutionSublist(str, "&", "&amp;");
      str := SubstitutionSublist(str, "<", "&lt;");
      PrintFormattedString(str);
      Print("\n</pre>\n\n");
    od;
    Print("\n\n</body>\n</html>\n");
  end;
  out := OutputTextFile(Concatenation(name, ".html"), false);
  SetPrintFormattingStatus(out, false);
  PrintTo1(out, fh);
  CloseStream(out);
  citations_by_year_outfile := "../../_data/bib_stats_year.yml";
  PrintTo(citations_by_year_outfile, "# Autogenerated by Doc/Bib/convbib.g\n\n");
  AppendTo(citations_by_year_outfile, "# Year/Number of citations\n\n");
  for i in [1..Length(years)] do
 	AppendTo(citations_by_year_outfile, years[i],": ", counts[i], "\n");
  od; 
  pos:=Length(bib[1])-Sum(counts);
  if pos<>0 then
    AppendTo(citations_by_year_outfile,"\"No year given, or year out of bounds\" : ",pos,"\n");
  fi;
  
  mscreport:=StatisticsByMSC();

  citations_by_msc_outfile := "../../_data/bib_stats_msc.yml";
  PrintTo(citations_by_msc_outfile, "# Autogenerated by Doc/Bib/convbib.g\n\n");
  AppendTo(citations_by_msc_outfile, "# Area/Primary/Secondary\n\n");
  for i in [1..Length(mscreport)] do
 	AppendTo(citations_by_msc_outfile, "- code: \"", mscreport[i][3],"\"\n");
 	AppendTo(citations_by_msc_outfile, "  name: ", mscreport[i][4], "\n");
 	AppendTo(citations_by_msc_outfile, "  primary: ", mscreport[i][1], "\n");
 	AppendTo(citations_by_msc_outfile, "  secondary: ", mscreport[i][2], "\n\n");
  od;  
  
  # changed to `plain' bibliography style. (This makes counting easier and
  # sorts according to the names, not the alpha abbreviations.)
  # ahulpke, 9/6/01
  PrintTo("FLtmpTeX.tex",
"\\documentclass[11pt]{article}\n",
"\\usepackage{amsfonts,url,fullpage,mathscinet}\n",
"\\usepackage[utf8x]{inputenc}\n",
"\\usepackage{polski}\n",
"\\def\\Bbb{\\mathbb}\n",
"\\def\\bold{\\boldmath}\n",
"\\def\\cprime{$'$}\n",
"\\def\\ssf{\\sf}\n",
"\\def\\refcno{see }\n",
"\\def\\text{\\mathrm}\n",
"\\def\\Dbar{\\leavevmode\\lower.6ex\\hbox to 0pt{\\hskip-.23ex \\accent\"16\\hss}D}\n",
"\\def\\refmr{}\\def\\endrefmr{}\n",
"\n",
"\\begin{document}\n",
"This list contains citations of the {\\sf GAP} system in scientific works.\n",
"It has been obtained from author's notices and searches in scientific citation databases\n",
"including {\\sf MathSciNet}, for which we acknowledge the American Mathematical Society.\n",
"\\vspace{15pt}\n",
"\\nocite{*}\n",
"\\begin{center}\n",
"\\textbf{\\Large ",header,"}\n",
"\\end{center}\n",
"\\def\\refname{}\n",
"\\bibliographystyle{plain}\n",
"\\bibliography{gap-head,",name,"nicertmp","}\n",
"\\end{document}\n");
  Exec(Concatenation("pdflatex FLtmpTeX; bibtex FLtmpTeX; pdflatex FLtmpTeX;",
       " pdflatex FLtmpTeX; mv FLtmpTeX.pdf ",name,".pdf; rm -f FLtmpTeX.* ",name,"nicertmp.bib"));
end;

# set fixed screen size to avoid formatting changes in fh()  output
SizeScreen([139,]);

# Add further lists here.
bib2niceandhtml("gap-published", "Published work which cites GAP",
Concatenation( "The GAP bibliography was partially obtained using the ",
"<a href=\"https://www.ams.org/mathscinet/\">MathSciNet</a> database. ",
"We acknowledge the <a href=\"https://www.ams.org/\">American Mathematical Society</a> ",
"for giving us such opportunity.") );
# GapNonMR is joined in gap-published - no need to duplicate (AH, 9/4/01)
#bib2niceandhtml("GapNonMR", "Work not in MR which cites GAP");

Exec("echo '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%.' >> gap-publishednicer.bib");
Exec("echo '%The GAP bibliography was partially obtained using the MathSciNet database.' >> gap-publishednicer.bib");
Exec("echo '%We acknowledge the American Mathematical Society for giving us such opportunity.' >> gap-publishednicer.bib");

QUIT;
