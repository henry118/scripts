#!/bin/sh

#
# gets clang tree from svn into ./llvm
# params (e.g., -r) can be specified on command line
#
rm -rf llvm
## get everything
# llvm
svn co $* http://llvm.org/svn/llvm-project/llvm/trunk llvm
# clang
cd llvm/tools
svn co $* http://llvm.org/svn/llvm-project/cfe/trunk clang
cd -
# extra
cd llvm/tools/clang/tools
svn co $* http://llvm.org/svn/llvm-project/clang-tools-extra/trunk extra
cd -
# compiler-rt
cd llvm/projects
svn co $* http://llvm.org/svn/llvm-project/compiler-rt/trunk compiler-rt
cd -
