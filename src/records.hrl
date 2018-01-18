-record(config, {
    window             :: enotepad_wx:window() | 'undefined',
    word_wrap  = false :: boolean(),
    status_bar = false :: boolean(),
    font               :: enotepad_font:font() | 'undefined'
}).
