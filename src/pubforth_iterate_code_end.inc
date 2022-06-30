    end;

    case Code^ of
    OP_END:     break;
    OP_LITERAL: Inc(Code, 1 + SizeOf(TValueN));
    OP_CALL:    Inc(Code, 1 + SizeOf(TValueXT));
    OP_PRINT_LITERAL_STR: Inc(Code, 1 + SizeOf(TValueN) + TValueN(Pointer(Code + 1)^));
    else
      Inc(Code);
    end;
  end;
