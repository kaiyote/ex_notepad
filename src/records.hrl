-record(font,{name,style,weight,size}).

-record(window, {
    x       :: integer(),
    y       :: integer(),
    width   :: non_neg_integer(),
    height  :: non_neg_integer()
}).

-record(config, {
    window             :: window() | 'undefined',
    word_wrap  = false :: boolean(),
    status_bar = false :: boolean(),
    font               :: font() | 'undefined'
}).

-record(statusbar, {
    control :: wxStatusBar:wxStatusBar(),
    frame   :: wxFrame:wxFrame()
}).
