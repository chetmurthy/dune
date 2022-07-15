module Array = Stdlib.ArrayLabels
module List = Stdlib.ListLabels
module String = Stdlib.StringLabels
module Bytes = Stdlib.Bytes

type t =
  | Opaque
  | Unit
  | Int of int
  | Int32 of int32
  | Int64 of int64
  | Nativeint of nativeint
  | Bool of bool
  | String of string
  | Bytes of bytes
  | Char of char
  | Float of float
  | Option of t option
  | List of t list
  | Array of t array
  | Tuple of t list
  | Record of (string * t) list
  | Variant of string * t list
  | Map of (t * t) list
  | Set of t list

let unsnoc l =
  match List.rev l with
  | last :: before_last -> Some (List.rev before_last, last)
  | [] -> None

let string_in_ocaml_syntax str =
  let is_space = function
    | ' ' ->
      (* don't need to handle tabs because those are already escaped *)
      true
    | _ -> false
  in
  let escape_protect_first_space s =
    let first_char =
      if String.length s > 0 && is_space s.[0] then "\\" else " "
    in
    first_char ^ String.escaped s
  in
  (* CR-someday aalekseyev: should use the method from
     [Dune_lang.prepare_formatter] so that the formatter can fit multiple lines
     on one line. *)
  match String.split_on_char ~sep:'\n' str with
  | [] -> assert false
  | first :: rest -> (
    match unsnoc rest with
    | None -> Pp.verbatim (Printf.sprintf "%S" first)
    | Some (middle, last) ->
      Pp.vbox
        (Pp.concat ~sep:Pp.newline
           (List.map ~f:Pp.verbatim
              (("\"" ^ String.escaped first ^ "\\n\\")
               :: List.map middle ~f:(fun s ->
                      escape_protect_first_space s ^ "\\n\\")
              @ [ escape_protect_first_space last ^ "\"" ]))))

let pp_sequence start stop x ~f =
  let open Pp.O in
  match x with
  | [] -> Pp.verbatim start ++ Pp.verbatim stop
  | _ ->
    let sep = ";" ^ String.make (String.length start) ' ' in
    Pp.hvbox
      (Pp.concat_mapi ~sep:Pp.cut x ~f:(fun i x ->
           Pp.box
             ((if i = 0 then Pp.verbatim (start ^ " ") else Pp.verbatim sep)
             ++ f x))
      ++ Pp.space ++ Pp.verbatim stop)

let rec pp =
  let open Pp.O in
  function
  | Opaque -> Pp.verbatim "<opaque>"
  | Unit -> Pp.verbatim "()"
  | Int i -> Pp.verbatim (string_of_int i)
  | Int32 i -> Pp.verbatim (Int32.to_string i)
  | Int64 i -> Pp.verbatim (Int64.to_string i)
  | Nativeint i -> Pp.verbatim (Nativeint.to_string i)
  | Bool b -> Pp.verbatim (string_of_bool b)
  | String s -> string_in_ocaml_syntax s
  | Bytes b -> string_in_ocaml_syntax (Bytes.to_string b)
  | Char c -> Pp.char c
  | Float f -> Pp.verbatim (string_of_float f)
  | Option None -> pp (Variant ("None", []))
  | Option (Some x) -> pp (Variant ("Some", [ x ]))
  | List xs -> pp_sequence "[" "]" xs ~f:pp
  | Array xs -> pp_sequence "[|" "|]" (Array.to_list xs) ~f:pp
  | Set xs ->
    Pp.box ~indent:2
      (Pp.verbatim "set" ++ Pp.space ++ pp_sequence "{" "}" xs ~f:pp)
  | Map xs ->
    Pp.box ~indent:2
      (Pp.verbatim "map" ++ Pp.space
      ++ pp_sequence "{" "}" xs ~f:(fun (k, v) ->
             Pp.box ~indent:2
               (pp k ++ Pp.space ++ Pp.char ':' ++ Pp.space ++ pp v)))
  | Tuple x ->
    Pp.box
      (Pp.char '('
      ++ Pp.concat_map ~sep:(Pp.seq (Pp.char ',') Pp.space) x ~f:pp
      ++ Pp.char ')')
  | Record fields ->
    pp_sequence "{" "}" fields ~f:(fun (f, v) ->
        Pp.box ~indent:2
          (Pp.verbatim f ++ Pp.space ++ Pp.char '=' ++ Pp.space ++ pp v))
  | Variant (v, []) -> Pp.verbatim v
  | Variant (v, xs) ->
    Pp.hvbox ~indent:2
      (Pp.concat
         [ Pp.verbatim v; Pp.space; Pp.concat_map ~sep:(Pp.char ',') xs ~f:pp ])

let to_string t = Format.asprintf "%a" Pp.to_fmt (pp t)

type 'a builder = 'a -> t

let unit () = Unit

let char x = Char x

let string x = String x

let int x = Int x

let int32 x = Int32 x

let int64 x = Int64 x

let nativeint x = Nativeint x

let float x = Float x

let bool x = Bool x

let pair f g (x, y) = Tuple [ f x; g y ]

let triple f g h (x, y, z) = Tuple [ f x; g y; h z ]

let list f l = List (List.map ~f l)

let array f a = Array (Array.map ~f a)

let option f x =
  Option
    (match x with
    | None -> None
    | Some x -> Some (f x))

let record r = Record r

let opaque _ = Opaque

let variant s args = Variant (s, args)

let hash = Stdlib.Hashtbl.hash

let compare x y = Ordering.of_int (compare x y)

let equal x y = x = y

let rec to_yojson = function
  | Opaque -> `String"Opaque"
  | Unit -> `Null
  | Int n -> `Int n
  | Int32 n  -> `Int (Int32.to_int n)
  | Int64 n -> `String (Int64.to_string n)
  | Nativeint n -> `Int (Nativeint.to_int n)
  | Bool b -> `Bool b
  | String s -> `String s
  | Bytes b -> `String (Bytes.to_string b)
  | Char c -> `String (String.make 1 c)
  | Float f -> `Float f
  | Option None -> `Null
  | Option (Some t) -> to_yojson t
  | List l -> `List (List.map ~f:to_yojson l)
  | Array l -> `List (List.map ~f:to_yojson (Array.to_list l))
  | Tuple l -> `List (List.map ~f:to_yojson l)
  | Record m -> `Assoc(List.map ~f:(fun (k,v) -> (k, to_yojson v)) m)
  | Variant (n, l) -> `List((`String n)::(List.map ~f:to_yojson l))
  | Map pl -> `List(List.map ~f:(fun (a,b) -> `List[to_yojson a; to_yojson b]) pl)
  | Set l ->  `List(List.map ~f:to_yojson l)

let pp_as_yojson x =
  let json = to_yojson x in
  Yojson.Basic.pretty_print Format.std_formatter json ;
  Format.(pp_print_flush std_formatter ())
