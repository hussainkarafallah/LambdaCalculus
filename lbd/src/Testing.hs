module Testing where

import Test.Hspec
import Test.Hspec.Attoparsec
import qualified Data.Text as T
import LambdaCalc
import qualified Data.Map as Map
import OutputMisc
import Parser
import Check

testset1 :: Spec
testset1 = do
  describe "test arithmetic" $ do
    it "should parse 'x+y+z*10-30+40'" $
       arith `shouldSucceedOn` ( T.pack("x + y + z * 10 - 30 + 40"))
    it "should parse 'x*1*y*2+3+4-5'" $
       arith `shouldSucceedOn` ( T.pack("x*1*y*2+3+4-5"))   
   
    
testset2 = do
    describe "test lambda" $ do
        it "should parse '\\x : Int .x $ 5' " $
            expr `shouldSucceedOn` ( T.pack "\\x : Int .x $ 5" )
        it "should parse '\\x : Int y : Int . x + y $" $
            expr `shouldSucceedOn` ( T.pack "\\x : Int y : Int . x + y $" )
        it "should parse '\\x : Bool . \\y : Bool . x + y $ $' " $
            expr `shouldSucceedOn` ( T.pack "\\x : Bool . \\y : Bool . x + y $ $" )
        it "should parse '\\x : Int y : Int . x + y $ (\\z : Int . z+1 $ 10) (2 + 9)' " $
            expr `shouldSucceedOn` ( T.pack "\\x : Int y : Int . x + y $ (\\ z : Int . z+1 $ 10) (2 + 9)' " )
        it "should parse simple equality check" $
            expr `shouldSucceedOn` ( T.pack "\\x : Int . if x = 10 ? x + 1 : x + 4 $")
        it "should parse simple max function" $
            expr `shouldSucceedOn` ( T.pack "\\x : Int y : Int . if x > y ? x : y $")
        it "should fail on arithmetic condition" $
            expr `shouldFailOn` (T.pack "\\x : Int . if x + 3 ? x + 5 : x - 1 $")
        it "should parse nested if" $
            expr `shouldSucceedOn` ( T.pack "\\x : Int . if x = 1 ? 100 : (if x = 2 ? 200 : 900) $")
        it "type parser" $
            tTypeParser `shouldSucceedOn` (T.pack "Int -> Int -> Int")
        it "higher order function #1" $
            expr `shouldSucceedOn` (T.pack "(\\x : Int -> Int . \\y : Int -> Int . x y $ $) (\\x : Int . x + 1 $) (\\x : Int . x * 2 $) 5")
        


testset3 = do
    describe "test type checking" $ do
        it "sum of 2 values int->int->int" $
            checktest "\\x : Int . \\y : Int . x + y $ $" `shouldBe` (Right $ TArr TInt (TArr TInt TInt))
        it "sum of 2 values applied to one is int->int" $
            checktest "\\x : Int . \\y : Int . x + y $ $ 4" `shouldBe` (Right $ TArr TInt TInt)
        it "and of 3 values is bool" $
            checktest "\\x : Bool y : Bool z : Bool . x & y & z $ True True True" `shouldBe` (Right TBool)
        it "simple parameter type error bool passed to int" $
            checktest "\\x : Int . x + 1 $ True" `shouldBe` (Left $ TypeMismatch TBool TInt)
        it "and beteween 2 integers should result in error" $
            checktest "\\x : Int y : Int . x & y $ 4 5" `shouldBe` (Left $ TypeMismatch TInt TBool)
        it "if with 2 different return clauses" $
            checktest "\\x : Int . if x = 5 ? x + 1 : True $ 5" `shouldBe` (Left $ TypeMismatch TInt TBool)
        it "if with 2 normal clauses" $
            checktest "\\x : Int . \\ y : Int . if x = y ? True : False $ $ " `shouldBe` (Right $ TArr TInt (TArr TInt TBool))
        it "higher order function  #1-1" $
            checktest "(\\x : Int -> Int . \\y : Int -> Int . x y $ $)" `shouldBe` ( Right (TArr (TArr TInt TInt) (TArr (TArr TInt TInt) (TArr TInt TInt)) ) )
        it "higher order function  #1-2" $
            checktest "(\\x : Int -> Int . \\y : Int -> Int . x y $ $)  (\\x : Int . x + 1 $)" `shouldBe` ( Right  (TArr (TArr TInt TInt) (TArr TInt TInt))  )
        it "higher order function  #1-3" $
            checktest "(\\x : Int -> Int . \\y : Int -> Int . x y $ $) (\\x : Int . x + 1 $) (\\x : Int . x * 2 $)" `shouldBe` ( Right  (TArr TInt TInt) )
    


testset4 = do
    describe "some evaluation tests" $ do
        it "logical circuits on 3 variables evaluation" $
            runeval Map.empty "\\x : Bool y : Bool z : Bool . (x & y) | (x & z) | (y & z) $ True False False" `shouldBe` (Literal (XBool False))   
        it "arithmetic with nested lambdas" $
            runeval Map.empty "\\x:Int y:Int z:Int . (\\a:Int.a+1 $ x) * (\\a:Int.a+2 $ y) * (\\a:Int.a+3 $ z) $ 0 0 0" `shouldBe` (Literal (XInt 6))
        it "function with redundant parameters reduction check" $
            runeval Map.empty "\\x : Int y : Int z : Int . 10 $ 500 250 20" `shouldBe` (Literal (XInt 10))
        it "max evaluation test" $
            runeval Map.empty "\\x : Int y : Int . if x > y ? x : y $ 3 5" `shouldBe` (Literal (XInt 5))
        it "equality test" $
            runeval Map.empty "\\x : Int y : Int . if x = y ? True : False $ 3 3" `shouldBe` (Literal (XBool True))
        it "factorial recursion" $
            runeval Map.empty "(rec \\f : Int -> Int . \\n : Int . if n=0 ? 1 : n * (f (n-1)) $ $) 5" `shouldBe` (Literal (XInt 120))
        it "nested if test1" $
            runeval Map.empty "\\x : Int . if x = 1 ? 100 : (if x = 2 ? 200 : 900) $ 100" `shouldBe` (Literal (XInt 900))
        it "nested if test2" $
            runeval Map.empty "\\x : Int . if x = 1 ? 100 : (if x = 2 ? 200 : 900) $ 2" `shouldBe` (Literal (XInt 200))
        it "fibonacci test" $
            runeval Map.empty "(rec \\f : Int -> Int . \\n : Int . if n=0 ? 1 : (if n = 1 ? 1 : (f (n-1)) + (f (n-2))) $ $) 5" `shouldBe` (Literal (XInt 8))
        it "pow test" $
            runeval Map.empty "(rec \\f : Int -> Int -> Int . \\n : Int . \\ m : Int . if m=1 ? n : n * (f n (m-1))  $ $ $) 2 3" `shouldBe` (Literal (XInt 8))
        it "higher order function eval #1" $
            runeval Map.empty "(\\x : Int -> Int . \\y : Int -> Int . x y $ $) (\\x : Int . x + 1 $) (\\x : Int . x * 2 $) 5" `shouldBe` (Literal (XInt 11))
        

        
    --    it "'(\\x : Int y : Int z : Int . x y z $) (\\x . x x $) (\\x . x $) x' must evaluate to x" $
    --        runeval Map.empty "(\\x y z . x y z $) (\\x . x x $) (\\x . x $) x" `shouldBe` (Var "x")
     --   it "'\\x.\\y.y$$ ((\\x.x$) (\\y.y$))' must evaluate to \\y.y" $
     --       runeval Map.empty "\\x.\\y.y$$ ((\\x.x$) (\\y.y$))" `shouldBe` (Abs "y" (Var "y"))
        


test :: IO()
test = do
    hspec testset1
    hspec testset2
    hspec testset3
    hspec testset4

