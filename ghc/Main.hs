
import Control.Monad
import Data.String
import Data.Time.Clock
import System.IO

timed :: String -> Int -> (a -> IO b) -> a -> IO ()
timed msg times act a = do
  buffering <- hGetBuffering stdout
  hSetBuffering stdout NoBuffering
  t0 <- getCurrentTime
  let dot _ = putStr ""; {-# noinline dot #-}
  replicateM_ times $ dot =<< act a
  t1 <- getCurrentTime
  let pad = replicate (20 - length msg) ' '
  putStrLn $ msg ++ ":" ++ pad
    ++ show ((nominalDiffTimeToSeconds $ diffUTCTime t1 t0 / fromIntegral times) * 1000000) ++ " us\n"
  hSetBuffering stdout buffering
{-# noinline timed #-}

data StrictList a = Nil | Cons a (StrictList a)

data RTm
  = RVar String
  | RApp RTm RTm
  | RLam String RTm


data Tm
  = Var Int
  | App Tm Tm
  | Lam String Tm
  deriving Show

elabVar :: StrictList String -> String -> Int
elabVar ns x = case ns of
  Cons x' ns | x == x' -> 0
             | True    -> elabVar ns x + 1
  _ -> undefined

elab' :: StrictList String -> RTm -> Tm
elab' ns = \case
  RVar x   -> Var (elabVar ns x)
  RApp t u -> App (elab' ns t) (elab' ns u)
  RLam x t -> Lam x (elab' (Cons x ns) t)

elab = elab' Nil

type Env = StrictList Val

data Val =
    VVar Int
  | VApp Val Val
  | VLam String Env Tm

vvar e (x :: Int) = case (e, x) of
  (Cons v _, 0) -> v
  (Cons _ e, x) -> vvar e (x - 1)
  _             -> undefined

eval e = \case
  Var x -> vvar e x
  App t u -> case eval e t of
    VLam _ e' t -> eval (Cons (eval e u) e') t
    t           -> VApp t (eval e u)
  Lam x t -> VLam x e t

conv (l :: Int) t t' = case (t, t') of
  (VVar x, VVar x') -> x == x'
  (VApp t u, VApp t' u') -> conv l t t' && conv l u u'
  (VLam x e t, VLam x' e' t') ->
    let v = VVar l in
    conv (l + 1) (eval (Cons v e) t) (eval (Cons v e') t')
  _ -> False

quote (l :: Int) = \case
  VVar x -> Var (l - x - 1)
  VApp t u -> App (quote l t) (quote l u)
  VLam x e t -> Lam x (quote (l + 1) (eval (Cons (VVar l) e) t))

eval0 = eval Nil
conv0 = conv 0
quote0 = quote 0
nf0 = quote0 . eval0

infixl 8 $$
($$) :: RTm -> RTm -> RTm
($$) = RApp
{-# inline ($$) #-}

instance IsString RTm where
  fromString = RVar

let_ :: String -> RTm -> RTm -> RTm
let_ x t u = RLam x u $$ t
{-# inline let_ #-}

prog :: Tm
prog = elab $
  let_ "zero" (RLam "s" $ RLam "z" "z") $
  let_ "suc" (RLam "n" $ RLam "s" $ RLam "z" $ "s" $$ ("n" $$ "s" $$ "z")) $
  let_ "n3"  ("suc" $$ ("suc" $$ ("suc" $$ "zero"))) $
  let_ "n5" ("suc" $$ ("suc" $$ ("suc" $$ ("suc" $$ ("suc" $$ "zero"))))) $
  let_ "add" (RLam "n" $ RLam "m" $ RLam "s" $ RLam "z" $ "n" $$ "s" $$ ("m" $$ "s" $$ "z")) $
  let_ "n10" ("add" $$ "n5" $$ "n5") $
  let_ "n15" ("add" $$ "n5" $$ "n10") $
  let_ "n20" ("add" $$ "n5" $$ "n15") $
  let_ "n23" ("add" $$ "n3" $$ "n20") $
  let_ "n25" ("add" $$ "n5" $$ "n20") $
  let_ "leaf" (RLam "n" $ RLam "l" $ "l") $
  let_ "node" (RLam "t1" $ RLam "t2" $ RLam "n" $ RLam "l" $ "n" $$ ("t1" $$ "n" $$ "l")
                                                                 $$ ("t2" $$ "n" $$ "l")) $
  let_ "mktree" (RLam "n" $ "n" $$ (RLam "t" $ "node" $$ "t" $$ "t") $$ "leaf") $
  "mktree" $$ treeSize

prog2 :: Tm
prog2 = elab $
  let_ "zero" (RLam "s" $ RLam "z" "z") $
  let_ "suc" (RLam "n" $ RLam "s" $ RLam "z" $ "s" $$ ("n" $$ "s" $$ "z")) $
  let_ "n3"  ("suc" $$ ("suc" $$ ("suc" $$ "zero"))) $
  let_ "n5"  ("suc" $$ ("suc" $$ ("suc" $$ ("suc" $$ ("suc" $$ "zero"))))) $
  let_ "add" (RLam "n" $ RLam "m" $ RLam "s" $ RLam "z" $ "n" $$ "s" $$ ("m" $$ "s" $$ "z")) $
  let_ "n10" ("add" $$ "n5" $$ "n5") $
  let_ "n15" ("add" $$ "n5" $$ "n10") $
  let_ "n20" ("add" $$ "n5" $$ "n15") $
  let_ "n23" ("add" $$ "n3" $$ "n20") $
  let_ "n25" ("add" $$ "n5" $$ "n20") $
  let_ "leaf" (RLam "n" $ RLam "l" $ "l") $
  let_ "node" (RLam "t1" $ RLam "t2" $ RLam "n" $ RLam "l" $ "n" $$ ("t1" $$ "n" $$ "l")
                                                                 $$ ("t2" $$ "n" $$ "l")) $
  let_ "mktree" (RLam "n" $ "n" $$ (RLam "t" $ "node" $$ "t" $$ "t") $$ "leaf") $
  "mktree" $$ treeSize $$ (RLam "_" $ RLam "_" $ "zero") $$ "zero"

prog3 :: Tm
prog3 = elab $
  let_ "zero" (RLam "s" $ RLam "z" "z") $
  let_ "suc" (RLam "n" $ RLam "s" $ RLam "z" $ "s" $$ ("n" $$ "s" $$ "z")) $
  let_ "n5"  ("suc" $$ ("suc" $$ ("suc" $$ ("suc" $$ ("suc" $$ "zero"))))) $
  let_ "n3"  ("suc" $$ ("suc" $$ ("suc" $$ "zero"))) $
  let_ "add" (RLam "n" $ RLam "m" $ RLam "s" $ RLam "z" $ "n" $$ "s" $$ ("m" $$ "s" $$ "z")) $
  let_ "n10" ("add" $$ "n5" $$ "n5") $
  let_ "n15" ("add" $$ "n5" $$ "n10") $
  let_ "n20" ("add" $$ "n5" $$ "n15") $
  let_ "n23" ("add" $$ "n3" $$ "n20") $
  let_ "n25" ("add" $$ "n5" $$ "n20") $
  let_ "mktree" (RLam "n" $ RLam "node" $ RLam "l" $
                 "n" $$ (RLam "x" $ "node" $$ "x" $$ "x") $$ "l") $
  "mktree" $$ treeSize

run = show . nf0 . elab

{-# noinline force #-}
force t = case nf0 t of
  Lam{} -> 0 :: Int
  _     -> 1 :: Int

data Tree = Node Tree Tree | Leaf Int
  deriving Show

maptree :: Tree -> Tree
maptree = \case
  Leaf n   -> Leaf (n + 100)
  Node l r -> Node (maptree l) (maptree r)

mktree :: Int -> Tree
mktree n = go n n where
  go 0 x = Leaf x
  go x 0 = Leaf x
  go n m = Node (go (n - 1) (m - 1)) (go (m - 1) (n - 1))

------------------------------------------------------------

iter :: Int
iter = 20 :: Int

treeSize :: RTm
treeSize = "n23"

mapTreeSize :: Int
mapTreeSize = 20

------------------------------------------------------------

main = do
  timed "Tree NF" iter (pure . force) prog
  -- timed "Tree Conv" iter (\t -> let v = eval0 t in pure $ conv0 v v) prog
  -- timed "Tree force" iter (pure . force) prog2
  -- timed "Tree NF share" iter (pure . force) prog3
  -- timed "Tree Conv share" iter (\t -> let v = eval0 t in pure $ conv0 v v) prog3

  -- timed "Maptree 1/2" iter (\n -> pure $ seq (maptree (mktree n)) ()) mapTreeSize
  -- timed "Maptree 2/3" iter (\n -> pure $ seq (maptree(maptree (mktree n))) ()) mapTreeSize
  -- timed "Maptree 3/4" iter (\n -> pure $ seq (maptree(maptree(maptree (mktree n)))) ()) mapTreeSize
  -- timed "Maptree 4/5" iter (\n -> pure $ seq (maptree(maptree(maptree(maptree(mktree n))))) ()) mapTreeSize
