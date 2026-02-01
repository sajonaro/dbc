const std = @import("std");

pub const Token = struct {
    text: []const u8,
    kind: TokenKind,
    len: usize,
};

pub const TokenKind = enum {
    keyword,
    identifier,
    string,
    number,
    operator,
    comment,
    punctuation,
    whitespace,
};

pub fn tokenize(sql: []const u8) []Token {
    // TODO: Implement SQL tokenizer
    _ = sql;
    return &.{};
}
