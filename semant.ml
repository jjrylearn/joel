(* Semantic checking for the MicroC compiler *)

open Ast
open Sast

module StringMap = Map.Make(String)

(* Check to see if a variable is in the given symbol table. *)
let rec find_variable (scope: symbol_table) name =
  try
    StringMap.find name scope.variables
  with Not_found ->
    match scope parent with
        Some(parent) -> find_variable parent name
      | _ -> raise Not_found

let convertToSAST (statements) =

  let symbols =
  {
    variables = StringMap.empty;
    parent = None;

  }

  let functions =
  {
    variables = StringMap.empty;
    parent = None;
  }

  let type_of_id s =
      try StringMap.find s symbols
      with Not_found -> raise (Failure ("undeclared identifier " ^ s))
  in

  (* Return a function from our symbol table *)
  let find_func s =
    try StringMap.find s function_decls
    with Not_found -> raise (Failure ("unrecognized function " ^ s))
  in

  let check_assign lvaluet rvaluet err =
     if lvaluet = rvaluet then lvaluet else raise (Failure err)
  in

  let rec convert_expr = function
    StringLiteral s -> (String, SStringLiteral s)
  | IntegerLiteral s -> (Num, SIntegerLiteral s)
  | FloatLiteral s -> (Num, SFloatLiteral s)
  | BoolLiteral s -> (Bool, SBoolLiteral s)
  | TableLiteral rows ->
    let check_row row =
      List.map convert_expr row
    in (Table, STableLiteral(List.map check_row rows))
  | ListLiteral row -> (List, SListLiteral(List.map convert_expr row))
  | DictLiteral row ->
    let convert_pair (e1, e2) =
      (convert_expr e1, convert_expr e2)
    in (Dict, SDictLiteral(List.map convert_pair row))
  | Binop(e1, op, e2) as e ->
    let (t1, e1') = expr e1
    and (t2, e2') = expr e2 in
    let same_type = t1 = t2 in
    let ty = match op with
        Add | Sub | Mult | Div | Mod when same_type && t1 = Num -> Num
      | Equal | Neq when same -> Bool
      | Less | Leq | Greater | Geq when same && t1 = Num -> Bool
      | And | Or | Xor when same && t1 = Bool -> Bool
      | Add when same && t1 = String -> String
      | _ -> raise (Failure("illegal binary operator."))
	      (* Failure ("illegal binary operator " ^   <<<<< pretty print needed
                       string_of_typ t1 ^ " " ^ string_of_op op ^ " " ^
                       string_of_typ t2 ^ " in " ^ string_of_expr e)) *)
      in (ty, SBinop((t1, e1'), op, (t2, e2')))
  | Unop(op, e1) as e ->
      let (t, e1') = expr e1 in
      let ty = match op with
        Neg when t = Num -> Num
      | Not when t = Bool -> Bool
      | _ -> raise (
          Failure("illegal unary operator.")
          (* Failure ("illegal unary operator " ^  <<<<< need pretty print
          string_of_uop op ^ string_of_typ t ^
                   " in " ^ string_of_expr ex) *)
        )
      in (ty, SUnop(op, (t, e')))
  | Pop(id, op) as e ->
    let t = type_of_id id in
    let ty = match op with
        Inc when t = Num -> Num
      | Dec when t = Num -> Num
      | _ -> raise (
          Failure("illegal use of pop operator.")
        )
    in (ty, Pop(id, op))
  | Call(fname, args) as call ->
      let fd = find_func fname in
      let param_length = List.length fd.formals in
      if List.length args != param_length then
        raise (Failure ("expecting " ^ string_of_int param_length ^
                              " arguments in " ^ string_of_expr call))
      else let check_call (ft, _) e =
        let (et, e') = convert_expr e in
        let err = "illegal argument found " ^ string_of_typ et ^
          " expected " ^ string_of_typ ft ^ " in " ^ string_of_expr e
        in (check_assign ft et err, e')
      in
      let args' = List.map check_call fd.formals args
      in (fd.typ, SCall(fname, args'))
  | Assign(id, e) as ex ->
      let lt = type_of_id id
      and (rt, e') = expr e in
      let err = "illegal assignment."
      (* let err = "illegal assignment " ^ string_of_typ lt ^ " = " ^
        string_of_typ rt ^ " in " ^ string_of_expr ex *)
      in (check_assign lt rt err, SAssign(var, (rt, e')))
  | AssignOp(id, op, e) as ex ->
      let lt = type_of_id id
      and (rt, e') = expr e in
      (* let err = "illegal assignment " ^ string_of_typ lt ^ " = " ^
        string_of_typ rt ^ " in " ^ string_of_expr ex *)
      let same_type = lt = rt in
      let ty = match op with
          Add | Sub | Mult | Div | Mod when same_type && lt = Num -> Num
        | Add when same && lt = String -> String
        | _ -> raise (Failure("illegal assignment."))
        in (ty, SAssign(var, (rt, e')))
  | Noexpr -> (Void, SNoexpr)
  | Id s -> (type_of_id s, SId s)

  in
  let convert_vardecl (t, id, e) = (t, convert_expr e) (* TODO: Add checking for id *)
  in

  let rec convert_statement = function
    Expr e -> convert_expr e
  | StmtVDecl v -> SStmtVDecl(convert_vardecl v) (* Returns a SStmtVDecl *)

  in List.map convert_statement statements
