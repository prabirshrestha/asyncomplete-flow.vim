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
    \ 'whitelist': ['javascript'],
    \ 'completor': function('asyncomplete#sources#flow#completor'),
    \ 'config': {
    \    'flowbin_path': expand('~/bin/flow')
    \  },
    \ }))
```

Note: `config` is optional. `flowbin_path` defaults to `flow`
i.e., `flow` binary should exist in the `PATH` if config is not specified.

Also make sure your javascript project is correctly initialized with `.flowconfig`.
