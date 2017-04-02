let s:jobs = {} " jobid: { buffer, tempfile, ctx, opt }
function! asyncomplete#sources#flow#completor(opt, ctx) abort
    let l:line = a:ctx['lnum'] - 1
    let l:col = a:ctx['col']

    let l:file = a:ctx['filepath']

    let l:tempfile = s:write_buffer_to_tempfile()

    if has('win32') || has('win64')
        let l:cmd = ['cmd', '/c', 'cd ' . expand('%:p:h') . ' && flow autocomplete --json ' . l:file . ' ' .  l:line . ' ' . l:col . ' < ' . l:tempfile]
    else
        let l:cmd = ['sh', '-c', 'cd ' . expand('%:p:h') . ' && flow autocomplete --json ' . l:file . ' ' .  l:line . ' ' . l:col . ' < ' . l:tempfile]
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
                call asyncomplete#log('flow', l:res)
                if !empty(l:res['result'])
                    let l:matches = map(l:res['result'], '{"word": v:val["name"], "dup": 1, "icase": 1, "menu": "JS"}')

                    let l:ctx = l:job['ctx']
                    let l:col = l:ctx['col']
                    let l:typed = l:ctx['typed']
                    let l:kw = matchstr(l:typed, '\v\S+$')
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

function! s:write_buffer_to_tempfile() abort
    let l:buf = getline(1, '$')
    if &encoding != 'utf-8'
        let l:buf = map(l:buf, 'iconv(v:val, &encoding, "utf-8")')
    endif

    if &l:fileformat == 'dos'
        " line2byte() depend on 'fileformat' option.
        " so if fileformat is 'dos', 'buf' must include '\r'.
        let l:buf = map(l:buf, 'v:val."\r"')
    endif

    let l:file = tempname()
    call writefile(l:buf, l:file)
    return l:file
endfunction
