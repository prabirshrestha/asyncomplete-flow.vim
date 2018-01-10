let s:is_win = has('win32') || has('win64')
let s:autotok = 'AUTO332'

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

    let l:params = { 'stdout_buffer': '', 'file': l:tempfile }

    let l:jobid = async#job#start(l:cmd, {
        \ 'on_stdout': function('s:handler', [a:opt, a:ctx, l:params]),
        \ 'on_stderr': function('s:handler', [a:opt, a:ctx, l:params]),
        \ 'on_exit': function('s:handler', [a:opt, a:ctx, l:params]),
        \ })

    call asyncomplete#log(l:cmd, l:jobid, l:tempfile)

    if l:jobid <= 0
        call delete(l:tempfile)
    endif
endfunction

function! s:handler(opt, ctx, params, id, data, event) abort
    if a:event ==? 'stdout'
        let a:params['stdout_buffer'] = a:params['stdout_buffer'] . join(a:data, "\n")
    elseif a:event ==? 'exit'
        if a:data == 0
            let l:res = json_decode(a:params['stdout_buffer'])
            if !empty(l:res) && !empty(l:res['result'])

                let l:config = get(a:opt, 'config', {})
                if get(l:config, 'show_typeinfo', 0)
                    let l:mapper = '{"word": v:val["name"], "dup": 1, "icase": 1, "menu": "[Flow]    " . v:val["type"]}'
                else
                    let l:mapper = '{"word": v:val["name"], "dup": 1, "icase": 1, "menu": "[Flow]"}'
                endif

                let l:matches = map(l:res['result'], l:mapper)

                let l:col = a:ctx['col']
                let l:typed = a:ctx['typed']
                let l:kw = matchstr(l:typed, '\w\+$')
                let l:kwlen = len(l:kw)
                let l:startcol = l:col - l:kwlen

                call asyncomplete#complete(a:opt['name'], a:ctx, l:startcol, l:matches)
            endif
        endif
        call delete(a:params['file'])
    elseif a:event ==? 'stdout'
        call asyncomplete#log(a:data)
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
