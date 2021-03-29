open Stdune

let dyn_of_pp tag pp =
  let open Dyn.Encoder in
  let rec conv = function
    | Pp.Ast.Nop -> constr "Nop" []
    | Seq (x, y) -> constr "Seq" [ conv x; conv y ]
    | Concat (x, y) -> constr "Concat" [ conv x; list conv y ]
    | Box (i, x) -> constr "Box" [ int i; conv x ]
    | Vbox (i, x) -> constr "Vbox" [ int i; conv x ]
    | Hbox x -> constr "Hbox" [ conv x ]
    | Hvbox (i, x) -> constr "Hvbox" [ int i; conv x ]
    | Hovbox (i, x) -> constr "Hovbox" [ int i; conv x ]
    | Verbatim s -> constr "Verbatim" [ string s ]
    | Char c -> constr "Char" [ char c ]
    | Break (x, y) ->
      let f = triple string int string in
      constr "Break" [ f x; f y ]
    | Newline -> constr "Newline" []
    | Tag (ta, t) -> constr "Tag" [ tag ta; conv t ]
    | Text s -> constr "Text" [ string s ]
  in
  conv
    (match Pp.to_ast pp with
    | Ok s -> s
    | Error () -> assert false)

let%expect_test "reproduce #2664" =
  (* https://github.com/ocaml/dune/issues/2664 *)
  let b = Buffer.create 100 in
  let f s = Buffer.add_string b ("\027[34m" ^ s ^ "\027[39m") in
  for i = 1 to 20 do
    f (string_of_int i)
  done;
  let pp =
    Buffer.contents b |> Ansi_color.parse
    |> dyn_of_pp (Dyn.Encoder.list Ansi_color.Style.to_dyn)
    |> Dyn.pp
  in
  Format.printf "%a@.%!" Pp.to_fmt pp;
  [%expect
    {|
    Vbox
      0,Seq
          Seq
            Seq
              Seq
                Seq
                  Seq
                    Seq
                      Seq
                        Seq
                          Seq
                            Seq
                              Seq
                                Seq
                                  Seq
                                    Seq
                                      Seq
                                        Seq
                                          Seq
                                            Seq
                                              Seq Nop,Tag [ "34" ],Verbatim "1",
                                              Tag
                                                [ "34" ],Verbatim "2",Tag
                                                                        [ "34" ],
                                                                        Verbatim
                                                                        "3",
                                          Tag
                                            [ "34" ],Verbatim "4",Tag
                                                                    [ "34" ],
                                                                    Verbatim
                                                                      "5",
                                      Tag
                                        [ "34" ],Verbatim "6",Tag
                                                                [ "34" ],
                                                                Verbatim
                                                                  "7",Tag
                                                                        [ "34" ],
                                                                        Verbatim
                                                                        "8",
                                Tag
                                  [ "34" ],Verbatim "9",Tag
                                                          [ "34" ],Verbatim "10",
                            Tag
                              [ "34" ],Verbatim "11",Tag [ "34" ],Verbatim "12",
                        Tag
                          [ "34" ],Verbatim "13",Tag [ "34" ],Verbatim "14",
                    Tag
                      [ "34" ],Verbatim "15",Tag [ "34" ],Verbatim "16",Tag
                                                                        [ "34" ],
                                                                        Verbatim
                                                                        "17",
              Tag
                [ "34" ],Verbatim "18",Tag [ "34" ],Verbatim "19",Tag
                                                                    [ "34" ],
                                                                    Verbatim
                                                                      "20" |}]