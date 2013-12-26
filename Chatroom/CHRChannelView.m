//
//  CHRChannelView.m
//  Chatroom
//
//  Created by Harshad on 26/12/13.
//  Copyright (c) 2013 Laughing Buddha Software. All rights reserved.
//

#import "CHRChannelView.h"

@implementation CHRChannelView {
    __weak UITextView *_messagesView;
    __weak UITextField *_composeField;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code

        UITextView *messagesView = [[UITextView alloc] initWithFrame:CGRectMake(10, 75, self.bounds.size.width - 20, self.bounds.size.height - 75)];
        [messagesView setAutoresizingMask:(UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth)];
        [messagesView setEditable:NO];
        [messagesView setBackgroundColor:[UIColor colorWithWhite:0.8 alpha:1.0f]];
        [messagesView setFont:[UIFont systemFontOfSize:16.0f]];
        [self addSubview:messagesView];
        _messagesView = messagesView;

        UITextField *composeField = [[UITextField alloc] initWithFrame:CGRectMake(10, 30, self.bounds.size.width - 20, 40)];
        [self addSubview:composeField];
        [composeField setBorderStyle:UITextBorderStyleLine];
        [composeField setAutoresizingMask:(UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin)];
        _composeField = composeField;

    }
    return self;
}

- (UITextView *)messagesView {
    return _messagesView;
}

- (UITextField *)composeField {
    return _composeField;
}



@end
