JavaScript source for asyncomplete.vim via Flow
===============================================

Provide javascript autocompletion source for [asyncomplete.vim](https://github.com/prabirshrestha/asyncomplete.vim) via
[Flow](https://flowtype.org)

### Installing

```vim
Plug 'prabirshrestha/async.vim'
Plug 'prabirshrestha/asyncomplete.vim'
Plug 'prabirshrestha/asyncomplete-flow.vim'
```

`async.vim` is required.

#### Registration

```vim
au User asyncomplete_setup call asyncomplete#register_source(asyncomplete#sources#flow#get_source_options({
    \ 'name': 'flow',
    \ 'allowlist': ['javascript'],
    \ 'completor': function('asyncomplete#sources#flow#completor'),
    \ 'config': {
    \    " Resolves 'flow' in the closest node_modules/.bin directory (in case
    \    " flow is installed via 'npm install flow-bin' locally). Falls back to
    \    " 'flowbin_path' (see below) if can't find it.
    \    'prefer_local': 1,
    \    " Path to 'flow' executable.
    \    'flowbin_path': expand('~/bin/flow'),
    \    " Displays additional typeinfo exposed by flow, if any is provided. 
    \    " Defaults to 0.
    \    'show_typeinfo': 1
    \  },
    \ }))
```

Note: `config` is optional. `flowbin_path` defaults to `flow`
i.e., `flow` binary should exist in the `PATH` if config is not specified.

Also make sure your javascript project is correctly initialized with `.flowconfig`.
