
// build & run in this folder:
// koka bench.kk -O2 -e --showtime
// version used: koka 3.1.1, gcc 11.4.0

import std/time/timer
import std/time/duration
import std/num/int64
import std/num/ddouble

type rtm
  RVar{x : string}
  RApp{t : rtm; u : rtm}
  RLam{x : string; t : rtm}

type tm
  Var{x : int64}
  App{t : tm; u : tm}
  Lam{x : string; t : tm}

fun show(t : tm) : string
  match t
    Var(x)    -> "Var(" ++ show(x) ++ ")"
    App(t, u) -> "App(" ++ show(t) ++ ", " ++ show(u) ++ ")"
    Lam(x, t) -> "Lam(" ++ x ++ ", " ++ show(t) ++ ")"

fun elabVar(ns : list<string>, x : string) : int64
  match ns
    Cons(x', ns) -> if x == x' then 0.int64 else elabVar(ns, x) + 1.int64
    _            -> 0.int64  // dummy, just to get rid of exn

fun elab'(ns : list<string>, t : rtm) : tm
  match t
    RVar(x)    -> Var(elabVar(ns, x))
    RApp(t, u) -> App(elab'(ns, t), elab'(ns, u))
    RLam(x, t) -> Lam(x, elab'(Cons(x, ns), t))

fun elab(t : rtm) elab'(Nil, t)

type value
  VVar{x : int64}
  VApp{t : value; u : value}
  VLam{x : string; e : list<value>; t : tm}

fun vvar(^e : list<value>, x : int64) : value
  match e
    Cons(v, e) -> if x == 0.int64 then v else vvar(e, x - 1.int64)
    _          -> VVar(0.int64) // dummy

fun eval(e : list<value>, t : tm) : <div> value
  match t
    Var(x) -> vvar(e, x)
    App(t, u) -> match eval(e, t)
      VLam(_, e', t) -> eval(Cons(eval(e, u), e'), t)
      t              -> {val uv = eval(e, u); VApp(t, uv)} // prevent TRMC here
    Lam(x, t) -> VLam(x, e, t)

fun conv(l : int64, ^t : value, ^t' : value) : <div> bool
  match (t, t')
    (VVar(x)   , VVar(x')    ) ->
      x == x'
    (VApp(t, u), VApp(t', u')) ->
      conv(l, t, t') && conv(l, u, u')
    (VLam(_, e, t), VLam(_, e', t')) ->
      val v = VVar(l)
      conv(l + 1.int64, eval(Cons(v, e), t), eval(Cons(v, e'), t'))
    _ ->
      False

fun quote(l : int64, t : value) : <div> tm
  match t
    VVar(x)       -> Var(l - x - 1.int64)
    VApp(t, u)    -> App(quote(l, t), quote(l, u))
    VLam(x, e, t) -> Lam(x, quote(l + 1.int64, eval(Cons(VVar(l), e), t)))

fun eval0(t)     eval(Nil, t)
fun conv0(t, t') conv(0.int64, t, t')
fun quote0(t)    quote(0.int64, t)
fun nf0(t)       quote0(eval0(t))

inline fun let(x:string, t:rtm, u:rtm) : rtm
  RApp(RLam(x, u), t)

inline fun rapp2(t, u, v) RApp(RApp(t, u), v)
inline fun rapp3(t, u, v, w) RApp(RApp(RApp(t, u), v), w)

inline val vx = RVar("x")
inline val vy = RVar("y")
inline val vz = RVar("z")
inline val vs = RVar("s")
inline val vt = RVar("t")
inline val vn = RVar("n")
inline val vm = RVar("m")
inline val vc = RVar("c")
inline val vl = RVar("l")
inline val vr = RVar("r")

val prog = elab(
  let("zero", RLam("s", RLam("z", vz)),
  let("suc", RLam("n", RLam("s", RLam("z", RApp(vs, rapp2(vn, vs, vz))))),
  let("n3", RApp(RVar("suc"), RApp(RVar("suc"), RApp(RVar("suc"), RVar("zero")))),
  let("n5", RApp(RVar("suc"), RApp(RVar("suc")
              , RApp(RVar("suc"), RApp(RVar("suc"), RApp(RVar("suc"), RVar("zero")))))),
  let("add", RLam("n", RLam("m", RLam("s", RLam("z", rapp2(vn, vs, rapp2(vm, vs, vz)))))),
  let("n10", rapp2(RVar("add"), RVar("n5"), RVar("n5")),
  let("n15", rapp2(RVar("add"), RVar("n5"), RVar("n10")),
  let("n20", rapp2(RVar("add"), RVar("n5"), RVar("n15")),
  let("n23", rapp2(RVar("add"), RVar("n3"), RVar("n20")),
  let("n25", rapp2(RVar("add"), RVar("n5"), RVar("n20")),
  let("leaf", RLam("n", RLam("l", RVar("l"))),
  let("node", RLam("t1", RLam("t2", RLam("n", RLam("l",
              rapp2(vn, rapp2(RVar("t1"), vn, vl), rapp2(RVar("t2"), vn, vl)))))),
  let("mktree", RLam("n", rapp2(vn, (RLam("t", rapp2(RVar("node"), vt, vt))), RVar("leaf"))),
  RApp(RVar("mktree"), treeSize)
  ))))))))))))))

val prog2 = elab(
  let("zero", RLam("s", RLam("z", vz)),
  let("suc", RLam("n", RLam("s", RLam("z", RApp(vs, rapp2(vn, vs, vz))))),
  let("n3", RApp(RVar("suc"), RApp(RVar("suc"), RApp(RVar("suc"), RVar("zero")))),
  let("n5", RApp(RVar("suc"), RApp(RVar("suc")
              , RApp(RVar("suc"), RApp(RVar("suc"), RApp(RVar("suc"), RVar("zero")))))),
  let("add", RLam("n", RLam("m", RLam("s", RLam("z", rapp2(vn, vs, rapp2(vm, vs, vz)))))),
  let("n10", rapp2(RVar("add"), RVar("n5"), RVar("n5")),
  let("n15", rapp2(RVar("add"), RVar("n5"), RVar("n10")),
  let("n20", rapp2(RVar("add"), RVar("n5"), RVar("n15")),
  let("n23", rapp2(RVar("add"), RVar("n3"), RVar("n20")),
  let("n25", rapp2(RVar("add"), RVar("n5"), RVar("n20")),
  let("leaf", RLam("n", RLam("l", RVar("l"))),
  let("node", RLam("t1", RLam("t2", RLam("n", RLam("l",
              rapp2(vn, rapp2(RVar("t1"), vn, vl), rapp2(RVar("t2"), vn, vl)))))),
  let("mktree", RLam("n", rapp2(vn, (RLam("t", rapp2(RVar("node"), vt, vt))), RVar("leaf"))),
  rapp2(RApp(RVar("mktree"), treeSize), RLam("_", RLam("_", RVar("leaf"))), RVar("leaf"))
  ))))))))))))))

val prog3 = elab(
  let("zero", RLam("s", RLam("z", vz)),
  let("suc", RLam("n", RLam("s", RLam("z", RApp(vs, rapp2(vn, vs, vz))))),
  let("n3", RApp(RVar("suc"), RApp(RVar("suc"), RApp(RVar("suc"), RVar("zero")))),
  let("n5", RApp(RVar("suc"), RApp(RVar("suc")
              , RApp(RVar("suc"), RApp(RVar("suc"), RApp(RVar("suc"), RVar("zero")))))),
  let("add", RLam("n", RLam("m", RLam("s", RLam("z", rapp2(vn, vs, rapp2(vm, vs, vz)))))),
  let("n10", rapp2(RVar("add"), RVar("n5"), RVar("n5")),
  let("n15", rapp2(RVar("add"), RVar("n5"), RVar("n10")),
  let("n20", rapp2(RVar("add"), RVar("n5"), RVar("n15")),
  let("n23", rapp2(RVar("add"), RVar("n3"), RVar("n20")),
  let("n25", rapp2(RVar("add"), RVar("n5"), RVar("n20")),
  let("mktree", RLam("n", RLam("node", RLam("l", rapp2(RVar("n")
                     , RLam("x", rapp2(RVar("node"), RVar("x"), RVar("x")))
                     , RVar("l"))))),
  RApp(RVar("mktree"), treeSize)
  ))))))))))))

fun run(t : rtm) : <div, exn> string
  show(nf0(elab(t)))

fun frc(t : tm) : <div, exn> int
  match nf0(t)
    Lam(_) -> 0
    _      -> 1

type tree
  Node{l: tree; r: tree}
  Leaf{x: int64}

fun maptree(t : tree) : tree
  match t
    Leaf(x) -> Leaf(x + 100.int64)
    Node(l, r) -> Node(maptree(l), maptree(r))

fun mktree(n : int64) : <div> tree
  fun go(n : int64, m : int64) : <div> tree
    if n == 0.int64 then
      Leaf(m)
    else if m == 0.int64 then
      Leaf(m)
    else Node(go(n - 1.int64, m - 1.int64),
              go(m - 1.int64, n - 1.int64))
  go(n, n)

fun frctree(t)
  match t
    Leaf(_) -> 0
    Node(_, _) -> 1

noinline fun timed(msg : string, times : int, act, start)
  val t0 = ticks()
  for(1, times, fn(_) {act(start); ()})
  val t1 = ticks()
  val diffnano = nano-seconds(t1 - t0)
  val avg  = (diffnano / times)/1000
  val pad = string(replicate(' ', 20 - length(list(msg))))
  println(msg ++ ":" ++ pad ++ show(avg) ++ " us")

noinline fun drop(x)
  ()

noinline fun timedDrop(x)
  val t0 = ticks()
  val _ = drop(x)
  val t1 = ticks()
  val diffnano = nano-seconds(t1 - t0)
  println("drop time: " ++ show(diffnano/1000))
  ()

val iter = 20
val mapTreeSize = 20.int64
val treeSize = RVar("n25")

fun main()

  timed("Tree NF", iter, frc, prog)
  // timed("Tree conv", iter, fn(p){val v = eval0(p); conv0(v, v)}, prog)
  // timed("Tree force", iter, frc, prog2)
  // timed("Tree NF share", iter, frc, prog3)
  // timed("Tree conv share", iter, fn(p){val v = eval0(p); conv0(v, v)}, prog3)
  // timed ("Maptree 1/2", iter, fn (n) {maptree(mktree(n))}, mapTreeSize)
  // timed ("Maptree 2/3", iter, fn (n) {maptree(maptree(mktree(n)))}, mapTreeSize)
  // timed ("Maptree 3/4", iter, fn (n) {maptree(maptree(maptree(mktree(n))))}, mapTreeSize)
  // timed ("Maptree 4/5", iter, fn (n) {maptree(maptree(maptree(maptree(mktree(n)))))}, mapTreeSize)

  // timedDrop(mktree(20.int64))
  // timedDrop(mktree(21.int64))
  // timedDrop(mktree(22.int64))
  // timedDrop(mktree(23.int64))
  // timedDrop(mktree(24.int64))
