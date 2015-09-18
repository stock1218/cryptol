{-# LANGUAGE DeriveGeneric #-}

module Cryptol.Parser.Name where

import Cryptol.Utils.Ident
import Cryptol.Utils.PP
import Cryptol.Utils.Panic (panic)

import           Control.DeepSeq
import qualified Data.Text as T
import           GHC.Generics (Generic)


-- Names -----------------------------------------------------------------------

-- | Names that originate in the parser.
data PName = UnQual !Ident
             -- ^ Unqualified names like @x@, @Foo@, or @+@.
           | Qual !ModName !Ident
             -- ^ Qualified names like @Foo::bar@ or @module::!@.
           | NewName !Pass !Int
             -- ^ Fresh names generated by a pass.
             deriving (Eq,Ord,Show,Generic)

-- | Passes that can generate fresh names.
data Pass = NoPat
          | MonoValues
            deriving (Eq,Ord,Show,Generic)

instance NFData PName
instance NFData Pass

mkUnqual :: Ident -> PName
mkUnqual  = UnQual

mkQual :: ModName -> Ident -> PName
mkQual  = Qual

getModName :: PName -> Maybe ModName
getModName (Qual ns _) = Just ns
getModName _           = Nothing

getIdent :: PName -> Ident
getIdent (UnQual n)    = n
getIdent (Qual _ n)    = n
getIdent (NewName p i) = Ident False (T.pack ("__" ++ pass ++ show i))
  where
  pass = case p of
           NoPat      -> "p"
           MonoValues -> "mv"

instance PP PName where
  ppPrec _ = ppPrefixName

instance PPName PName where
  ppPrefixName n = optParens (isInfixIdent i) (pfx <> pp i)
    where
    i   = getIdent n
    pfx = case getModName n of
            Just ns -> pp ns <> text "::"
            Nothing -> empty

  ppInfixName n
    | isInfixIdent i = panic "AST" [ "non-symbol infix name:" ++ show n ]
    | otherwise      = pfx <> pp i
    where
    i   = getIdent n
    pfx = case getModName n of
            Just ns -> pp ns <> text "::"
            Nothing -> empty