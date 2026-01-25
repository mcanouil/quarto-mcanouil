// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil
//
// Bibliography configuration
// Pandoc template partial for rendering bibliographies

// ============================================================================
// Bibliography setup
// ============================================================================

$if(citations)$
$if(csl)$

#set bibliography(style: "$csl$")
$elseif(bibliographystyle)$

#set bibliography(style: "$bibliographystyle$")
$endif$
$if(bibliography)$

#bibliography(($for(bibliography)$"$bibliography$"$sep$,$endfor$))
$endif$
$endif$
