-- |
-- Module      :  $Header$
-- Copyright   :  (c) 2013-2016 Galois, Inc.
-- License     :  BSD3
-- Maintainer  :  cryptol@galois.com
-- Stability   :  provisional
-- Portability :  portable

{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE PatternGuards #-}
{-# LANGUAGE RecordWildCards #-}
module Cryptol.ModuleSystem.Interface (
    Iface(..)
  , IfaceDecls(..)
  , IfaceTySyn, ifTySynName
  , IfaceNewtype
  , IfaceDecl(..), mkIfaceDecl

  , genIface
  , ifacePrimMap
  ) where

import           Cryptol.ModuleSystem.Name
import           Cryptol.TypeCheck.AST
import           Cryptol.Utils.Ident (ModName)

import qualified Data.Map as Map

import GHC.Generics (Generic)
import Control.DeepSeq

import Prelude ()
import Prelude.Compat


-- | The resulting interface generated by a module that has been typechecked.
data Iface = Iface
  { ifModName :: !ModName
  , ifPublic  :: IfaceDecls
  , ifPrivate :: IfaceDecls
  } deriving (Show, Generic, NFData)

data IfaceDecls = IfaceDecls
  { ifTySyns   :: Map.Map Name IfaceTySyn
  , ifNewtypes :: Map.Map Name IfaceNewtype
  , ifDecls    :: Map.Map Name IfaceDecl
  } deriving (Show, Generic, NFData)

instance Monoid IfaceDecls where
  mempty      = IfaceDecls Map.empty Map.empty Map.empty
  mappend l r = IfaceDecls
    { ifTySyns   = Map.union (ifTySyns l)   (ifTySyns r)
    , ifNewtypes = Map.union (ifNewtypes l) (ifNewtypes r)
    , ifDecls    = Map.union (ifDecls l)    (ifDecls r)
    }
  mconcat ds  = IfaceDecls
    { ifTySyns   = Map.unions (map ifTySyns   ds)
    , ifNewtypes = Map.unions (map ifNewtypes ds)
    , ifDecls    = Map.unions (map ifDecls    ds)
    }

type IfaceTySyn = TySyn

ifTySynName :: TySyn -> Name
ifTySynName = tsName

type IfaceNewtype = Newtype

data IfaceDecl = IfaceDecl
  { ifDeclName    :: !Name
  , ifDeclSig     :: Schema
  , ifDeclPragmas :: [Pragma]
  , ifDeclInfix   :: Bool
  , ifDeclFixity  :: Maybe Fixity
  , ifDeclDoc     :: Maybe String
  } deriving (Show, Generic, NFData)

mkIfaceDecl :: Decl -> IfaceDecl
mkIfaceDecl d = IfaceDecl
  { ifDeclName    = dName d
  , ifDeclSig     = dSignature d
  , ifDeclPragmas = dPragmas d
  , ifDeclInfix   = dInfix d
  , ifDeclFixity  = dFixity d
  , ifDeclDoc     = dDoc d
  }

-- | Generate an Iface from a typechecked module.
genIface :: Module -> Iface
genIface m = Iface
  { ifModName = mName m
  , ifPublic  = IfaceDecls
    { ifTySyns = tsPub
    , ifNewtypes = ntPub
    , ifDecls  = dPub
    }
  , ifPrivate = IfaceDecls
    { ifTySyns = tsPriv
    , ifNewtypes = ntPriv
    , ifDecls  = dPriv
    }
  }
  where

  (tsPub,tsPriv) =
      Map.partitionWithKey (\ qn _ -> qn `isExportedType` mExports m ) (mTySyns m)
  (ntPub,ntPriv) =
      Map.partitionWithKey (\ qn _ -> qn `isExportedType` mExports m ) (mNewtypes m)

  (dPub,dPriv) =
      Map.partitionWithKey (\ qn _ -> qn `isExportedBind` mExports m)
      $ Map.fromList [ (qn,mkIfaceDecl d) | dg <- mDecls m
                                          , d  <- groupDecls dg
                                          , let qn = dName d
                                          ]


-- | Produce a PrimMap from an interface.
--
-- NOTE: the map will expose /both/ public and private names.
ifacePrimMap :: Iface -> PrimMap
ifacePrimMap Iface { .. } =
  PrimMap { primDecls = merge primDecls
          , primTypes = merge primTypes }
  where
  merge f = Map.union (f public) (f private)

  public  = ifaceDeclsPrimMap ifPublic
  private = ifaceDeclsPrimMap ifPrivate

ifaceDeclsPrimMap :: IfaceDecls -> PrimMap
ifaceDeclsPrimMap IfaceDecls { .. } =
  PrimMap { primDecls = Map.fromList (newtypes ++ exprs)
          , primTypes = Map.fromList (newtypes ++ types)
          }
  where
  exprs    = [ (nameIdent n, n) | n <- Map.keys ifDecls    ]
  newtypes = [ (nameIdent n, n) | n <- Map.keys ifNewtypes ]
  types    = [ (nameIdent n, n) | n <- Map.keys ifTySyns   ]
