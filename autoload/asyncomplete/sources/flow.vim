let s:is_win = has('win32') || has('win64')
let s:autotok = 'AUTO332'
let s:jobs = {} " jobid: { buffer, tempfile, ctx, opt }
function! asyncomplete#sources#flow#completor(opt, ctx) abort
    let l:file = a:ctx['filepath']
    if empty(l:file)
        return
    endif

    let l:tempfile = s:write_buffer_to_tempfile(a:ctx)

    let l:config = get(a:opt, 'config', {})
    if get(l:config, 'prefer_local', 1)
        let l:flowbin_path = s:resolve_flowbin_path(l:file, 'flow')
    else
        let l:flowbin_path = get(l:config, 'flowbin_path', 'flow')
    endif

    if s:is_win
        let l:cmd = ['cmd', '/c', 'cd "' . expand('%:p:h') . '" && ' . l:flowbin_path . ' autocomplete --json "' . l:file . '" < "' . l:tempfile . '"']
    else
        let l:cmd = ['sh', '-c', 'cd "' . expand('%:p:h') . '" && ' . l:flowbin_path . ' autocomplete --json "' . l:file . '" < "' . l:tempfile . '"']
    endif

    let l:jobid = async#job#start(l:cmd, {
        \ 'on_stdout': function('s:handler'),
        \ 'on_exit': function('s:handler'),
        \ })

    call asyncomplete#log(l:cmd, l:jobid, l:tempfile)

    if l:jobid > 0
        let s:jobs[l:jobid] = { 'buffer': '', 'tempfile': l:tempfile, 'ctx': a:ctx, 'opt': a:opt }
    else
        call delete(l:tempfile)
    endif
endfunction

function! s:handler(id, data, event) abort
    if a:event == 'stdout'
        if has_key(s:jobs, a:id)
            let s:jobs[a:id]['buffer'] = s:jobs[a:id]['buffer'] . join(a:data, "\n")
        endif
    elseif a:event == 'exit'
        if has_key(s:jobs, a:id)
            let l:job = s:jobs[a:id]
            call delete(l:job['tempfile'])
            if a:data == 0
                let l:res = json_decode(l:job['buffer'])
                if !empty(l:res) && !empty(l:res['result'])
                    let l:matches = map(l:res['result'], '{"word": v:val["name"], "dup": 1, "icase": 1, "menu": "[Flow]"}')

                    let l:ctx = l:job['ctx']
                    let l:col = l:ctx['col']
                    let l:typed = l:ctx['typed']
                    let l:kw = matchstr(l:typed, '\w\+$')
                    let l:kwlen = len(l:kw)
                    let l:startcol = l:col - l:kwlen

                    call asyncomplete#complete(l:job['opt']['name'], l:ctx, l:startcol, l:matches)
                endif
            endif
            unlet s:jobs[a:id]
        endif
    endif
endfunction

function! asyncomplete#sources#flow#get_source_options(opts)
   return extend(extend({}, a:opts), {
       \ 'refresh_pattern': '\(\k\+$\|\.$\)',
       \ })
endfunction

let s:cached_flowbin_path_by_dir = {} " dir: <path to flow>

function! s:resolve_flowbin_path(file, fallback)
    let l:dir = fnamemodify(a:file, ':h')
    " cap the cache so it won't grow unlimited, ideally we should use LRU
    " strategy instead
    if len(s:cached_flowbin_path_by_dir) > 100
      let s:cached_flowbin_path_by_dir = {}
    endif
    if !has_key(s:cached_flowbin_path_by_dir, l:dir)
        let l:node_dir = asyncomplete#utils#find_nearest_parent_directory(a:file, 'node_modules')
        if s:is_win && filereadable(l:node_dir . '/.bin/flow.cmd')
            let s:cached_flowbin_path_by_dir[l:dir] = l:node_dir . './.bin/flow.cmd'
        elseif filereadable(l:node_dir . '/.bin/flow')
            let s:cached_flowbin_path_by_dir[l:dir] = l:node_dir . './.bin/flow'
        else
            let s:cached_flowbin_path_by_dir[l:dir] = a:fallback
        endif
    endif
    return s:cached_flowbin_path_by_dir[l:dir]
endfunction

function! s:write_buffer_to_tempfile(ctx) abort
    let l:lines = getline(1, '$')
    let l:lnum = a:ctx['lnum']
    let l:col = a:ctx['col']

    " Insert the base and magic token into the current line.
    let l:curline = l:lines[l:lnum - 1]
    let l:lines[l:lnum - 1] = l:curline[:l:col - 1] . s:autotok . l:curline[l:col:]

    let l:file = tempname()
    call writefile(l:lines, l:file)
    return l:file
endfunction
