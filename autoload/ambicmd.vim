" You can use ambiguous command.
" Version: 0.5.1
" Authors: thinca <thinca+vim@gmail.com>
"          Shougo <Shougo.Matsu (at) gmail.com>
"          tyru   <tyru.exe@gmail.com>
" License: zlib License

if !exists('g:ambicmd#build_rule')
  let g:ambicmd#build_rule = 'ambicmd#default_rule'
endif

function! ambicmd#default_rule(cmd)
  return [
  \   '\c^' . a:cmd . '$',
  \   '\c^' . a:cmd,
  \   '\c' . a:cmd,
  \   '\C^' . substitute(toupper(a:cmd), '.', '\0\\l*', 'g') . '$',
  \   '\C' . substitute(toupper(a:cmd), '.', '\0\\l*', 'g'),
  \   '.*' . substitute(a:cmd, '.', '\0.*', 'g')
  \ ]
endfunction

let s:search_pattern = '\v/[^/]*\\@<!%(\\\\)*/|\?[^?]*\\@<!%(\\\\)*\?'
let s:line_specifier =
\   '\v%(\d+|[.$]|''\S|\\[/?&])?%([+-]\d*|' . s:search_pattern . ')*'
let s:range = '\v%(\%|' . s:line_specifier .
\              '%([;,]' . s:line_specifier . ')*)?'
let s:command_extractor = '\v^' . s:range . '\zs\a\w*!?$'

" Expand ambiguous command.
function! ambicmd#expand(key)
  " 'v'/'V'/'<C-v>' are used used by a search by a visual mode.
  let cmdline = index(['c', 'v', 'V', "\<C-v>"], mode()) != -1
  if cmdline && getcmdtype() !=# ':'
    return a:key
  endif
  let line =  cmdline ? getcmdline() : getline('.')
  let pos  = (cmdline ? getcmdpos()  : col('.')) - 1
  if line[pos] =~# '\S'
    return a:key
  endif
  let cmdb = matchstr(line[: pos - 1], s:command_extractor)
  let [cmd, bang] = matchlist(cmdb, '^\(.\{-}\)\(!\?\)$')[1 : 2]

  let state = exists(':' . cmd)
  if cmd ==# '' || (cmd =~# '^\l' && state == 1) || state == 2
    return a:key
  endif

  let cmdlist = s:get_cmd_list()

  let prekey = !cmdline && pumvisible() ? "\<C-y>" : ''
  let filtered_lists = []
  " Search matching.
  for pat in call(g:ambicmd#build_rule, [cmd], {})
    let filtered = filter(copy(cmdlist), 'v:val =~? pat')
    call add(filtered_lists, filtered)
    if len(filtered) == 1
      let newcmd = filtered[0] . bang
      return prekey . repeat("\<C-h>", strlen(cmdb)) . newcmd . a:key
    endif
  endfor

  " Expand the head of common part.
  for filtered in filtered_lists
    if empty(filtered)
      continue
    endif
    let common = filtered[0]
    for str in filtered[1 :]
      let common = matchstr(common, '^\C\%[' . str . ']')
    endfor
    if len(cmd) <= len(common)
      return prekey . repeat("\<C-h>", len(cmdb)) . common . "\<C-d>"
    endif
  endfor

  return a:key
endfunction

function! s:get_cmd_list() abort
  redir => cmdlistredir
  silent! command
  redir END
  return map(split(cmdlistredir, "\n")[1 :],
  \          'matchstr(v:val, ''\u\w*'')')
endfunction
