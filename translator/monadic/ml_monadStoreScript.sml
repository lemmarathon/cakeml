(* This file defines theorems and lemma used in the ml_monadStoreLib *)

open preamble evaluateTheory semanticPrimitivesTheory
open set_sepTheory cfTheory cfStoreTheory cfTacticsLib terminationTheory
open cfHeapsBaseTheory cfAppTheory ml_monad_translatorBaseTheory
open packLib

val _ = new_theory "ml_monadStore"

val HCOND_EXTRACT = save_thm("HCOND_EXTRACT", cfLetAutoTheory.HCOND_EXTRACT);

val SEP_EXISTS_SEPARATE = save_thm("SEP_EXISTS_SEPARATE",
  List.hd(SPEC_ALL SEP_CLAUSES |> CONJUNCTS) |> GSYM |> GEN_ALL);

val SEP_EXISTS_INWARD = save_thm("SEP_EXISTS_INWARD",
  List.nth(SPEC_ALL SEP_CLAUSES |> CONJUNCTS, 1) |> GSYM |> GEN_ALL);

val ALLOCATE_ARRAY_evaluate = Q.store_thm("ALLOCATE_ARRAY_evaluate",
  `!env s n xname xv.
    (nsLookup env.v (Short xname) = SOME xv) ==>
    eval_rel s env (App Aalloc [Lit (IntLit &n); Var (Short xname)])
      (s with refs := s.refs ++ [Varray (REPLICATE n xv)])
      (Loc (LENGTH s.refs))`,
  rw[evaluate_def, do_app_def, store_alloc_def, ml_progTheory.eval_rel_def]
  \\ rw[state_component_equality]);

val ALLOCATE_EMPTY_RARRAY_evaluate = Q.store_thm("ALLOCATE_EMPTY_RARRAY_evaluate",
  `!env s.
     eval_rel s env (App Opref [App AallocEmpty [Con NONE []]])
       (s with refs := s.refs ++ [Varray []] ++ [Refv (Loc (LENGTH s.refs))])
       (Loc (LENGTH s.refs + 1))`,
  rw[evaluate_def, do_app_def, do_opapp_def, do_con_check_def, build_conv_def,
     store_alloc_def,state_component_equality, ml_progTheory.eval_rel_def]);

val LIST_REL_REPLICATE = Q.store_thm("LIST_REL_REPLICATE",
  `!n TYPE x v. TYPE x v ==> LIST_REL TYPE (REPLICATE n x) (REPLICATE n v)`,
  rw[] \\ Cases_on `n`
  \\ metis_tac[LIST_REL_REPLICATE_same]);

val GC_INWARDS = Q.store_thm("GC_INWARDS",
  `GC * A = A * GC`, SIMP_TAC std_ss [STAR_COMM]);

val GC_DUPLICATE_0 = Q.store_thm("GC_DUPLICATE_0",
  `H * GC = H * GC * GC`, rw[GSYM STAR_ASSOC, GC_STAR_GC]);

val GC_DUPLICATE_1 = Q.store_thm("GC_DUPLICATE_1",
  `A * (B * GC * C) = A * GC * (B * GC * C)`,
   SIMP_TAC std_ss [GSYM STAR_ASSOC, GC_INWARDS, GC_STAR_GC]);

val GC_DUPLICATE_2 = Q.store_thm("GC_DUPLICATE_2",
  `A * (B * GC) = A * GC * (B * GC)`,
  ASSUME_TAC (Thm.INST [``C : hprop`` |-> ``emp : hprop``] GC_DUPLICATE_1)
  \\ FULL_SIMP_TAC std_ss [GSYM STAR_ASSOC, SEP_CLAUSES])

val GC_DUPLICATE_3 = Q.store_thm("GC_DUPLICATE_3",
 `A * GC * B = GC * (A * GC * B)`,
  SIMP_TAC std_ss [GSYM STAR_ASSOC, GC_INWARDS, GC_STAR_GC])

val store2heap_aux_decompose_store1 = Q.store_thm(
 "store2heap_aux_decompose_store1",
 `A (store2heap_aux n a) ==>
  B (store2heap_aux (n + LENGTH a) b) ==>
  (A * B) (store2heap_aux n (a ++ b))`,
 rw[STAR_def, SPLIT_def]
 \\ instantiate
 \\ rw[Once UNION_COMM]
 >- fs[store2heap_aux_append_many]
 \\ fs[store2heap_aux_DISJOINT]);

val store2heap_aux_decompose_store2 = Q.store_thm(
 "store2heap_aux_decompose_store2",
 `A (store2heap_aux n [a]) ==>
  B (store2heap_aux (n + 1) b) ==>
  (A * B) (store2heap_aux n (a::b))`,
 rw[]
 \\ `a::b = [a]++b` by fs[]
 \\ POP_ASSUM(fn x => PURE_ONCE_REWRITE_TAC[x])
 \\ irule store2heap_aux_decompose_store1
 \\ fs[]);

val cons_to_append = Q.store_thm("cons_to_append", `a::b::c = [a; b]++c`, fs[]);

val append_empty = Q.store_thm("append_empty", `a = a ++ []`, fs[]);

val H_STAR_GC_SAT_IMP = Q.store_thm("H_STAR_GC_SAT_IMP",
 `H s ==> (H * GC) s`,
  rw[STAR_def]
  \\ qexists_tac `s`
  \\ qexists_tac `{}`
  \\ rw[SPLIT_emp2, SAT_GC]);

val store2heap_REF_SAT = Q.store_thm("store2heap_REF_SAT",
 `((Loc l) ~~> v) (store2heap_aux l [Refv v])`,
  fs[store2heap_aux_def]
  >> fs[REF_def, SEP_EXISTS_THM, HCOND_EXTRACT, cell_def, one_def]);

val store2heap_eliminate_ffi_thm = Q.store_thm(
  "store2heap_eliminate_ffi_thm",
  `H (store2heap s.refs) ==> (GC * H) (st2heap (p:'ffi ffi_proj) s)`,
  rw[]
  \\ Cases_on `p`
  \\ fs[st2heap_def, STAR_def]
  \\ qexists_tac `ffi2heap (q, r) s.ffi`
  \\ qexists_tac `store2heap s.refs`
  \\ fs[SAT_GC]
  \\ PURE_ONCE_REWRITE_TAC[SPLIT_SYM]
  \\ fs[st2heap_SPLIT_FFI]);

val rarray_exact_thm = Q.store_thm("rarray_exact_thm",
 `((l = l' + 1) /\ (n = l')) ==>
  RARRAY (Loc l) av (store2heap_aux n [Varray av; Refv (Loc l')])`,
  rw[]
  \\ rw[RARRAY_def]
  \\ rw[SEP_EXISTS_THM]
  \\ qexists_tac `Loc l'`
  \\ PURE_REWRITE_TAC[Once STAR_COMM]
  \\ `[Varray av; Refv (Loc l')] = [Varray av] ++ [Refv (Loc l')]` by fs[]
  \\ POP_ASSUM(fn x => PURE_REWRITE_TAC[x])
  \\ irule store2heap_aux_decompose_store1
  \\ conj_tac
  >-(rw[ARRAY_def, SEP_EXISTS_THM, HCOND_EXTRACT, cell_def, one_def, store2heap_aux_def])
  \\ rw[REF_def, SEP_EXISTS_THM, HCOND_EXTRACT, cell_def, one_def, store2heap_aux_def]);

val farray_exact_thm = Q.store_thm("farray_exact_thm",
 `(n = l) ==>
  ARRAY (Loc l) av (store2heap_aux n [Varray av])`,
 rw[ARRAY_def, SEP_EXISTS_THM, HCOND_EXTRACT, cell_def, one_def, store2heap_aux_def]);

val eliminate_inherited_references_thm = Q.store_thm(
  "eliminate_inherited_references_thm",
 `!a b. H (store2heap_aux (LENGTH a) b) ==>
  (GC * H) (store2heap_aux 0 (a++b))`,
  rw[]
  \\ fs[STAR_def]
  \\ instantiate
  \\ qexists_tac `store2heap_aux 0 a`
  \\ fs[SPEC_ALL store2heap_aux_SPLIT |> Thm.INST [``n:num`` |-> ``0:num``]
		 |> SIMP_RULE arith_ss [], SAT_GC]);

val eliminate_substore_thm = Q.store_thm("eliminate_substore_thm",
 `(H1 * GC * H2) (store2heap_aux (n + LENGTH a) b) ==>
  (H1 * GC * H2) (store2heap_aux n (a++b))`,
  rw[]
  \\ PURE_ONCE_REWRITE_TAC[GC_DUPLICATE_3]
  \\ rw[Once STAR_def]
  \\ qexists_tac `store2heap_aux n a`
  \\ qexists_tac `store2heap_aux (n + LENGTH a) b`
  \\ simp[SAT_GC, store2heap_aux_SPLIT]);

val eliminate_store_elem_thm = Q.store_thm("eliminate_store_elem_thm",
 `(H1 * GC * H2) (store2heap_aux (n + 1) b) ==>
  (H1 * GC * H2) (store2heap_aux n (a::b))`,
  rw[]
  \\ PURE_ONCE_REWRITE_TAC[GC_DUPLICATE_3]
  \\ rw[Once STAR_def]
  \\ PURE_ONCE_REWRITE_TAC[CONS_APPEND]
  \\ qexists_tac `store2heap_aux n [a]`
  \\ qexists_tac `store2heap_aux (n + (LENGTH [a])) b`
  \\ simp[SAT_GC, store2heap_aux_SPLIT]);

val H_STAR_empty = Q.store_thm("H_STAR_empty",
`H * emp = H`, rw[SEP_CLAUSES]);

val H_STAR_TRUE = Q.store_thm("H_STAR_TRUE",
`(H * &T = H) /\ (&T * H = H)`, fs[SEP_CLAUSES]);

(* Information about the subscript exceptions *)
val Conv_Subscript = EVAL ``sub_exn_v`` |> concl |> rand
(* val Stamp_Subscript = Conv_Subscript |> rator |> rand |> rand *)

(* Terms used by the ml_monadStore *)
val parsed_terms = save_thm("parsed_terms",
  pack_list (pack_pair pack_string pack_term)
    [("emp",``emp : hprop``),
     ("APPEND",``list$APPEND : 'a list -> 'a list -> 'a list``),
     ("CONS",``list$CONS : 'a -> 'a list -> 'a list``),
     ("REF",``REF``),
     ("RARRAY",``RARRAY``),
     ("ARRAY",``ARRAY``),
     ("SOME",``SOME : 'a -> 'a option``),
     ("one",``1 : num``),
     ("cond",``set_sep$cond : bool -> hprop``),
     ("get_refs",``\(state : 'a semanticPrimitives$state). state.refs``),
     ("opref_expr",``\name. (App Opref [Var (Short name)])``),
     ("empty_v_list",``[] : v list``),
     ("empty_v_store",``[] : v store``),
     ("empty_alpha_list",``[] : 'a list``),
     ("nsLookup_env_short", ``\(env : v sem_env) name. nsLookup env.v (Short name)``),
     ("Conv_Subscript", Conv_Subscript)
    ]);

(* Types used by the ml_monadStore *)
val parsed_types = save_thm("parsed_types",
  pack_list (pack_pair pack_string pack_type)
    [("hprop",``:hprop``),
     ("v",``:v``),
     ("ffi_state",``:'ffi semanticPrimitives$state``),
     ("ffi_ffi_proj",``:'ffi ffi_proj``),
     ("lookup_ret",``:num # stamp``)
    ]);

val _ = export_theory();
