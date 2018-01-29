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

-record(wxFindDialogEvent_ex, {type, find_string, replace_string, flags}).

-record(ctrl, {
    dialog              :: wxDialog:wxDialog(),
    main_panel          :: wxPanel:wxPanel(),
    find_box            :: wxTextCtrl:wxTextCtrl(),
    replace_box         :: wxTextCtrl:wxTextCtrl() | 'undefined',
    find_next_button    :: wxButton:wxButton(),
    replace_button      :: wxButton:wxButton() | 'undefined',
    replace_all_button  :: wxButton:wxButton() | 'undefined',
    cancel_button       :: wxButton:wxButton(),
    whole_word_checkbox :: wxCheckBox:wxCheckBox() | 'undefined',
    match_case_checkbox :: wxCheckBox:wxCheckBox() | 'undefined',
    up_radio            :: wxRadioButton:wxRadioButton() | 'undefined',
    down_radio          :: wxRadioButton:wxRadioButton() | 'undefined'
}).

-record(ctrlstate, {
    find    :: string(),
    replace :: string(),
    flags   :: integer()
}).

-record(state, {
    parent      :: wxWindow:wxWindow(),
    listener    :: pid() | 'undefined',
    controls    :: ctrl(),
    frdata      :: fr_data()
}).

-record(wx_state, {
    frame      :: wxFrame:wxFrame(),
    textctrl   :: wxStyledTextCtrl:wxStyledTextCtrl(),
    menu       :: wxMenuBar:wxMenuBar(),
    statusbar  :: enotepad_statusbar:statusbar(),
    font       :: wxFont:wxFont(),
    print      :: enotepad_print:enotepad_print(),
    fr_data    :: wxFindReplaceData:wxFindReplaceData() | 'undefined',
    fr_dialog  :: wxFindReplaceDialog_ex:wxFindReplaceDialog_ex() | 'undefined',

    filename                :: string() | 'undefined',
    select_start = -1       :: integer(),
    select_end = -1         :: integer(),
    is_selecting = false    :: boolean(),
    position = -1           :: integer(),
    empty_state = true      :: boolean()
}).
