open Tezos_lwt_result_stdlib.Lwtreslib.Bare.Monad

type 'action io_error = {
  action : 'action;
  unix_code : Unix.error;
  caller : string;
  arg : string;
}

let with_open_file ~flags ?(perm = 0o640) filename task_ =
  let open Lwt_syntax in
  let* rfd =
    Lwt.catch
      (fun () ->
        let* r = Lwt_unix.openfile filename flags perm in
        Lwt.return (Ok r))
      (function
        | Unix.Unix_error (unix_code, caller, arg) ->
          Lwt.return (Error { action = `Open; unix_code; caller; arg })
        | exn -> raise exn) in
  match rfd with
  | Error _ as r -> Lwt.return r
  | Ok fd ->
    let* res = task_ fd in
    Lwt.catch
      (fun () ->
        let* () = Lwt_unix.close fd in
        Lwt.return (Ok res))
      (function
        | Unix.Unix_error (unix_code, caller, arg) ->
          Lwt.return (Error { action = `Close; unix_code; caller; arg })
        | exn -> raise exn)

let with_open_out ?(overwrite = true) file task =
  let flags =
    let open Unix in
    if overwrite then
      [O_WRONLY; O_CREAT; O_TRUNC; O_CLOEXEC]
    else
      [O_WRONLY; O_CREAT; O_CLOEXEC] in
  with_open_file ~flags file task

(* This is to avoid file corruption *)
let with_atomic_open_out ?(overwrite = true) ?temp_dir filename f =
  let open Lwt_result_syntax in
  let temp_file =
    Filename.temp_file ?temp_dir (Filename.basename filename) ".tmp" in
  let* res = with_open_out ~overwrite temp_file f in
  Lwt.catch
    (fun () ->
      let*! () = Lwt_unix.rename temp_file filename in
      return res)
    (function
      | Unix.Unix_error (unix_code, caller, arg) ->
        Lwt.return (Error { action = `Rename; unix_code; caller; arg })
      | exn -> raise exn)

let end_of_file_if_zero nb_read =
  if nb_read = 0 then Lwt.fail End_of_file else Lwt.return_unit
let write_string ?(pos = 0) ?len descr buf =
  let len =
    match len with
    | None -> String.length buf - pos
    | Some l -> l in
  let rec inner pos len =
    if len = 0 then
      Lwt.return_unit
    else
      let open Lwt_syntax in
      let* nb_written = Lwt_unix.write_string descr buf pos len in
      let* () = end_of_file_if_zero nb_written in
      inner (pos + nb_written) (len - nb_written) in
  inner pos len

let save file_name =
  let open Lwt_result_syntax in
  let file = file_name in
  let*! v =
    with_atomic_open_out file (fun chan ->
        let content = "json" in
        write_string chan content) in
  let* () = Lwt.return (Result.map_error (fun _ -> [Error file]) v) in
  return file

let () =
  let arg = Sys.argv.(1) in
  match Lwt_main.run (save arg) with
  | Ok response -> print_string response
  | Error _ ->
    prerr_endline "Request timed out";
    exit 1
