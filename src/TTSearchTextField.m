#import "Three20/TTSearchTextField.h"
#import "Three20/TTNavigationCenter.h"
#import "Three20/TTBackgroundView.h"
#import "Three20/TTTableFieldCell.h"

///////////////////////////////////////////////////////////////////////////////////////////////////

static const CGFloat kShadowHeight = 24;

///////////////////////////////////////////////////////////////////////////////////////////////////

@interface TTSearchTextFieldInternal : NSObject <UITextFieldDelegate> {
  TTSearchTextField* _textField;
  id<UITextFieldDelegate> _delegate;
}

@property(nonatomic,assign) id<UITextFieldDelegate> delegate;

- (id)initWithTextField:(TTSearchTextField*)textField;

@end

@implementation TTSearchTextFieldInternal

@synthesize delegate = _delegate;

- (id)initWithTextField:(TTSearchTextField*)textField {
  if (self = [super init]) {
    _textField = textField;
  }
  return self;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// UITextFieldDelegate

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
  if ([_delegate respondsToSelector:@selector(textFieldShouldBeginEditing:)]) {
    return [_delegate textFieldShouldBeginEditing:textField];
  } else {
    return YES;
  }
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
  if ([_delegate respondsToSelector:@selector(textFieldDidBeginEditing:)]) {
    [_delegate textFieldDidBeginEditing:textField];
  }
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {
  if ([_delegate respondsToSelector:@selector(textFieldShouldEndEditing:)]) {
    return [_delegate textFieldShouldEndEditing:textField];
  } else {
    return YES;
  }
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
  if ([_delegate respondsToSelector:@selector(textFieldDidEndEditing:)]) {
    return [_delegate textFieldDidEndEditing:textField];
  }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range
    replacementString:(NSString *)string {
  if (![_textField shouldUpdate:!string.length]) {
    return NO;
  }

  SEL sel = @selector(textField:shouldChangeCharactersInRange:replacementString:);
  if ([_delegate respondsToSelector:sel]) {
    return [_delegate textField:textField shouldChangeCharactersInRange:range
      replacementString:string];
  } else {
    return YES;
  }
}

- (BOOL)textFieldShouldClear:(UITextField *)textField {
  [_textField shouldUpdate:YES];

  if ([_delegate respondsToSelector:@selector(textFieldShouldClear:)]) {
    return [_delegate textFieldShouldClear:textField];
  } else {
    return YES;
  }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  if (!_textField.searchesAutomatically) {
    [_textField search];
  }
  
  if ([_delegate respondsToSelector:@selector(textFieldShouldReturn:)]) {
    return [_delegate textFieldShouldReturn:textField];
  } else {
    return YES;
  }
}

@end

///////////////////////////////////////////////////////////////////////////////////////////////////

@implementation TTSearchTextField

@synthesize searchSource = _searchSource, tableView = _tableView,
  searchesAutomatically = _searchesAutomatically, showsDoneButton = _showsDoneButton,
  showsDarkScreen = _showsDarkScreen;

- (id)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _internal = [[TTSearchTextFieldInternal alloc] initWithTextField:self];
    _searchSource = nil;
    _tableView = nil;
    _shadowView = nil;
    _screenView = nil;
    _searchTimer = nil;
    _previousRightBarButtonItem = nil;
    _searchesAutomatically = YES;
    _showsDoneButton = NO;
    _showsDarkScreen = NO;

    self.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    self.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.returnKeyType = UIReturnKeySearch;
    self.enablesReturnKeyAutomatically = YES;
    
    [self addTarget:self action:@selector(didBeginEditing)
      forControlEvents:UIControlEventEditingDidBegin];
    [self addTarget:self action:@selector(didEndEditing)
      forControlEvents:UIControlEventEditingDidEnd];

    [super setDelegate:_internal];
  }
  return self;
}

- (void)dealloc {
  [_searchSource.delegates removeObject:self];
  [_searchSource release];
  [_internal release];
  [_tableView release];
  [_shadowView release];
  [_screenView release];
  [_previousRightBarButtonItem release];
  [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (void)showDoneButton:(BOOL)show {
  UIViewController* controller = [TTNavigationCenter defaultCenter].frontViewController;
  if (controller) {
    if (show) {
      _previousRightBarButtonItem = [controller.navigationItem.rightBarButtonItem retain];
      
      UIBarButtonItem* doneButton = [[UIBarButtonItem alloc]
      initWithBarButtonSystemItem:UIBarButtonSystemItemDone
      target:self action:@selector(doneAction)];
      [controller.navigationItem setRightBarButtonItem:doneButton animated:YES];
    } else {
      [controller.navigationItem setRightBarButtonItem:_previousRightBarButtonItem animated:YES];
      [_previousRightBarButtonItem release];
      _previousRightBarButtonItem = nil;
    }
  }
}

- (void)showDarkScreen:(BOOL)show {
  if (show && !_screenView) {
    _screenView = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
    _screenView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
    _screenView.frame = [self rectForSearchResults:NO];
    _screenView.alpha = 0;
    [_screenView addTarget:self action:@selector(doneAction)
      forControlEvents:UIControlEventTouchUpInside];
  }
  
  if (show) {
    [self.superviewForSearchResults addSubview:_screenView];
  }
  
  [UIView beginAnimations:nil context:nil];
  [UIView setAnimationDuration:TT_TRANSITION_DURATION];
  [UIView setAnimationDelegate:self];
  [UIView setAnimationDidStopSelector:@selector(screenAnimationDidStop)];

  _screenView.alpha = show ? 1 : 0;
  
  [UIView commitAnimations];
}

- (NSString*)searchText {
  if (!self.hasText) {
    return @"";
  } else {
    NSCharacterSet* whitespace = [NSCharacterSet whitespaceCharacterSet];
    return [self.text stringByTrimmingCharactersInSet:whitespace];
  }
}

- (void)autoSearch {
  if (_searchesAutomatically) {
    [self search];
  }
}

- (void)dispatchUpdate:(NSTimer*)timer {
  _searchTimer = nil;
  [self autoSearch];
}

- (void)delayedUpdate {
  [_searchTimer invalidate];
  _searchTimer = [NSTimer scheduledTimerWithTimeInterval:0 target:self
    selector:@selector(dispatchUpdate:) userInfo:nil repeats:NO];
}

- (void)screenAnimationDidStop {
  if (_screenView.alpha == 0) {
    [_screenView removeFromSuperview];
  }
}

- (void)doneAction {
  self.text = @"";
  [self resignFirstResponder];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// UITextField

- (id<UITextFieldDelegate>)delegate {
  return _internal.delegate;
}

- (void)setDelegate:(id<UITextFieldDelegate>)delegate {
  _internal.delegate = delegate;
}

- (void)setText:(NSString*)text {
  [super setText:text];
  [self autoSearch];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// UITableViewDelegate

- (CGFloat)tableView:(UITableView*)tableView heightForRowAtIndexPath:(NSIndexPath*)indexPath {
  id item = [_searchSource objectForRowAtIndexPath:indexPath];
  Class cls = [_searchSource cellClassForObject:item];
  return [cls tableView:_tableView rowHeightForItem:item];
}

- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
  if ([_internal.delegate respondsToSelector:@selector(textField:didSelectObject:)]) {
    id object = [_searchSource objectForRowAtIndexPath:indexPath];
    UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
    if (cell.selectionStyle != UITableViewCellSeparatorStyleNone) {
      [_internal.delegate performSelector:@selector(textField:didSelectObject:) withObject:self
        withObject:object];      
    }
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// TTTableViewDataSourceDelegate

- (void)dataSourceLoaded:(id<TTTableViewDataSource>)dataSource {
  [_tableView reloadData];
}

- (void)dataSource:(id<TTTableViewDataSource>)dataSource didFailWithError:(NSError*)error {
  [_tableView reloadData];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// UIControlEvents

- (void)didBeginEditing {
  UIScrollView* scrollView = (UIScrollView*)[self firstParentOfClass:[UIScrollView class]];
  scrollView.scrollEnabled = NO;
  scrollView.scrollsToTop = NO;

  if (_showsDoneButton) {
    [self showDoneButton:YES];
  }
  if (_showsDarkScreen) {
    [self showDarkScreen:YES];
  }
  if (self.hasText) {
    [self showSearchResults:YES];
  }
}

- (void)didEndEditing {
  UIScrollView* scrollView = (UIScrollView*)[self firstParentOfClass:[UIScrollView class]];
  scrollView.scrollEnabled = YES;
  scrollView.scrollsToTop = YES;
  
  [self showSearchResults:NO];
  
  if (_showsDoneButton) {
    [self showDoneButton:NO];
  }
  if (_showsDarkScreen) {
    [self showDarkScreen:NO];
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setSearchSource:(id<TTSearchSource>)searchSource {
  if (searchSource != _searchSource) {
    [_searchSource.delegates removeObject:self];
    [_searchSource release];
    _searchSource = [searchSource retain];
    [_searchSource.delegates addObject:self];
  }
}

- (BOOL)hasText {
  return self.text.length;
}

- (void)search {
  if (_searchSource) {
    NSString* text = self.searchText;
    [self showSearchResults:!!text.length];
    [_searchSource textField:self searchForText:text];
    _tableView.hidden = ![_tableView numberOfRowsInSection:0];
  }
}

- (void)showSearchResults:(BOOL)show {
  if (show) {
    if (!_tableView) {
      _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
      _tableView.backgroundColor = [TTAppearance appearance].searchTableBackgroundColor;
      _tableView.separatorColor = [TTAppearance appearance].searchTableSeparatorColor;
      _tableView.dataSource = _searchSource;
      _tableView.delegate = self;
      _tableView.scrollsToTop = NO;
      _tableView.hidden = YES;
    }

    if (!_shadowView) {
      _shadowView = [[TTBackgroundView alloc] initWithFrame:CGRectZero];
      _shadowView.style = TTDrawInnerShadow;
      _shadowView.backgroundColor = [UIColor clearColor];
      _shadowView.contentMode = UIViewContentModeRedraw;
      _shadowView.userInteractionEnabled = NO;
    }

    if (!_tableView.superview) {
      _tableView.frame = [self rectForSearchResults:YES];
      _shadowView.frame = CGRectMake(_tableView.left, _tableView.top,
        _tableView.width, kShadowHeight);
      
      UIView* superview = self.superviewForSearchResults;
      [superview addSubview:_tableView];
      [superview addSubview:_shadowView];
    }
  } else {
    UIView* parent = self.superview;
    if (parent) {
      [_tableView removeFromSuperview];
      [_shadowView removeFromSuperview];
    }
  }
}

- (UIView*)superviewForSearchResults {
  UIScrollView* scrollView = (UIScrollView*)[self firstParentOfClass:[UIScrollView class]];
  return scrollView ? scrollView : self.superview;
}

- (CGRect)rectForSearchResults:(BOOL)withKeyboard {
  UIView* superview = self.superviewForSearchResults;
  CGFloat height = self.height;
  CGFloat keyboardHeight = withKeyboard ? KEYBOARD_HEIGHT : 0;
  CGFloat tableHeight = self.window.height - (superview.screenY + height + keyboardHeight);
  
  CGFloat y = 0;
  UIView* view = self;
  while (view != superview) {
    y += view.top;
    view = view.superview;
  }  
  
  return CGRectMake(0, y + self.height-1, superview.frame.size.width, tableHeight+1);
}

- (BOOL)shouldUpdate:(BOOL)emptyText {
  [self delayedUpdate];
  return YES;
}

@end
