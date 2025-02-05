# Introduction

On 2024-May-17, Chris Dodd added an implementation of for loops to
p4c.

This directory contains some P4 programs intended to test the
properties of this implementation.

Here are some short names used in this article for specific versions
of the p4c source code:

+ v1 - p4c git SHA d5df09b77201b87ad9356c45ae2ffdb1c67b35d1 dated 2024-Jun-04
+ v2 - p4c git SHA 32e73964a43941ae10ef5ac1e0dbd3a9d7975ed3 dated 2024-Jun-21
+ v3 - p4c git SHA fd23e565cb4eae51e72a07b04bd9963d4e45c5b2 dated 2024-Aug-03
+ v4 - p4c git SHA 9fcd7d5985f22ae6ff437a30dfb613a1347d8079 dated 2024-Oct-13


```bash
make all-good
make -i all-errors
```


## Summary of results with p4c source version "v4"

List of programs compiled via `make all-good` that have loops:

| Errors? | Warnings? | Loop kind | Loop var modified in body? | Other loop exprs constant? | Other loop exprs modified in body? | Loop unrolled? | Program |
| ------- | --------- | --------- | -------------------------- | -------------------------- | ---------------------------------- | -------------- | ------- |
|  no |  no | 3-clause |  no | yes | N/A | yes | loop-var-can-be-declared-before-loop1.p4 |
|  no |  no | 3-clause |  no |  no |  no |  no | loop-var-exprs-not-constant1.p4 |
|  no |  no | 3-clause |  no |  no | yes |  no | loop-var-exprs-not-constant2.p4 |
|  no |  no | 3-clause | yes | yes | N/A |  no | loop-var-modifiable-in-body1.p4 |
|  no |  no | 3-clause | yes |  no |  no |  no | loop-var-modifiable-in-body2.p4 |
|  no |  no | 3-clause | yes |  no | yes |  no | loop-var-modifiable-in-body3.p4 |
|  no |  no | 3-clause |  no |  no |  no | yes | loop-vars-multiple-in-initializer1.p4 |
|  no |  no |  in-list |  no | yes | N/A |  no | loop-var-in-list-const-list1.p4 |
|  no |  no |  in-list |  no |  no |  no |  no | loop-var-in-list-elems-variable1.p4 |
|  no |  no |  in-list |  no |  no | yes |  no | loop-var-in-list-elems-modified1.p4 |
|  no |  no |  in-list |  no |  no | yes |  no | loop-var-in-list-elems-modified2.p4 |
|  no |  no |  in-list | yes | yes | N/A |  no | loop-var-in-list4.p4 |
|  no |  no |  in-list | yes |  no |  no |  no | loop-var-in-list-elems-variable2.p4 |
|  no |  no |  in-list | yes |  no | yes |  no | loop-var-in-list-elems-modified3.p4 |
|  no |  no | in-range |  no | yes | N/A | yes | loop-var-in-range-const-range1.p4 |
|  no |  no | in-range |  no |  no |  no |  no | loop-var-in-range-var-range1.p4 |
|  no |  no | in-range |  no |  no | yes |  no | loop-var-in-range-var-range2.p4 |
|  no |  no | in-range |  no |  no | yes | yes | loop-var-in-range-bounds-modified1.p4 |
|  no |  no | in-range | yes | yes | N/A | yes | loop-var-in-range-modifiable-in-body1.p4 |
|  no |  no | in-range | yes |  no |  no |  no | loop-var-in-range-modifiable-in-body2.p4 |
|  no |  no | in-range | yes |  no | yes |  no | loop-var-in-range-modifiable-in-body3.p4 |

These programs are currently not unrolled by p4c as of version v4, and
are good candidates for figuring out how to make them work with bmv2
backend:

+ loop-var-exprs-not-constant1.p4
+ loop-var-exprs-not-constant2.p4
+ loop-var-modifiable-in-body1.p4
+ loop-var-modifiable-in-body2.p4
+ loop-var-modifiable-in-body3.p4
+ loop-var-in-range-var-range1.p4
+ loop-var-in-range-var-range2.p4
+ loop-var-in-range-modifiable-in-body2.p4
+ loop-var-in-range-modifiable-in-body3.p4

There are several P4 programs that are not currently unrolled that use
`for (typeRef var in {list,of,values})`, but I did not include them in
the list immediately above because my sincere hope is that someone
implements the unrolling code for this in p4c, and it might be a bit
tricky to create all of the necessary temporary values in the p4c bmv2
backend to store and use the values of list elements evaluated before
the first time the loop body is executed.

I believe this can be accomplished by modifying only the p4c bmv2
backend, although the techniques of doing so is different depending
upon whether the loop is inside of the body of an action, or outside
of the body of an action but inside of a control:

+ Inside the body of an action, use `_jump` and/or `_jump_if_zero`
  primitive instructions inside of the action to create the necessary
  control flow.
+ Outside the body of an action, use the `conditional` node type
  inside of a BMv2 `pipeline` object to create either conditional
  branches, or unconditional branches by making the true/false next
  node the same.  The next node can be a "backwards" jump.

Note: I believe that the only reason that
`loop-var-in-range-bounds-modified1.p4` is able to unroll the loop,
even though the range includes a variable `m`, is because shortly
before the loop the program has the assignment `m = 3;`, and the
compiler is able to propagate that value 3 into the loop's range
expression before the loop-unrolling pass is reached.  If you change
the program so that `m`'s value is not easily inferred as a constant,
then the compiler no longer unrolls the loop.

Note: In examining the midend P4 files created by the command `p4test
--dump <dir> --top4 FrontEndLast,FrontEndDump,MidEndLast <prog>.p4`
for 3-clause loops, it appears that loop variables that are declared
with scope local to the loop body _do_ have their definitions moved
earlier in the code, to the beginning of the enclosing `control`.
That should make things easier for the BMv2 backend code to generate
JSON from, as it does not need to examine the loop IR to decide what
local variables to create, nor does it need to worry about creating
unique names for them -- they are already made unique by p4c.

Note: In examining the output for `for (typeRef var in min..max)`
loops, it appears that the `typeRef` remains in the midend IR, but the
variable is _also_ moved earlier in the code as well.  This seems like
a minor bug to be fixed in p4c.  I created
https://github.com/p4lang/p4c/issues/5106 to track this.


List of programs compiled via `make all-good` that _do not_ have loops:

| Errors? | Warnings? | Program |
| ------- | --------- | ------- |
|  no | yes | var-shadowing-test1.p4 |
|  no | yes | var-shadowing-test2.p4 |

List of programs compiled via `make -i all-errors`:

+ err-var-is-not-compile-time-known-value1.p4
+ err-loop-var-not-in-scope-outside-of-loop1.p4
+ err-loop-var-cannot-be-used-in-slice1.p4
+ err-loop-var-in-range-no-typeref1.p4
+ err-loop-var-in-range-no-typeref2.p4


## Non-error cases


### Is it allowed to modify a loop variable in the loop body?

#### v1, v2, v3

Yes.

```bash
$ mkdir -p tmp
$ p4test --dump tmp --top4 FrontEndLast,FrontEndDump,MidEndLast loop-var-modifiable-in-body1.p4
[ no errors or warnings.  See output file tmp/loop-var-modifiable-in-body1-0003-MidEnd_47_MidEndLast.p4 ]
```

In v1, v2, the output files for `FrontEndLast` and `MidEndLast` appear
incorrect, as they do not update the loop variable `i`.  This was a
bug in the compiler that Chris Dodd fixed via the following PR, before
v3.

+ https://github.com/p4lang/p4c/pull/4783


### Is a loop variable declared before loop in scope after loop body?

#### v1, v2, v3

Yes.  Good!

```bash
$ p4test --dump tmp --top4 FrontEndLast,FrontEndDump,MidEndLast loop-var-can-be-declared-before-loop1.p4
[ no errors or warnings.  See output file tmp/loop-var-can-be-declared-before-loop1-0003-MidEnd_47_MidEndLast.p4 ]
```

The `MidEndLast` file looks correct to me, but not as optimized as it
could be, e.g. it contains dead assignments to `n_0` overwritten by
immediately-following assignments, and lots of constant folding
undone.


### Compiler supports initialization and expressions with non-constant values

#### v1, v2, v3

Yes.  Good!

```bash
$ mkdir -p tmp
$ p4test --dump tmp --top4 FrontEndLast,FrontEndDump,MidEndLast loop-var-exprs-not-constant1.p4
[ no errors or warnings, and MidEnd output file looks correct. ]
```


### Compiler supports multiple initializations in a 3-clause for loop

#### v1, v2, v3

Yes.  Good!

```bash
$ mkdir -p tmp
$ p4test --dump tmp --top4 FrontEndLast,FrontEndDump,MidEndLast loop-vars-multiple-in-initializer1.p4
[ no errors or warnings, and MidEnd output file looks correct. ]
```


## Error cases


### Can const identifiers be used as slice indexes?

#### v3

```bash
$ mkdir -p tmp
$ p4test --dump tmp --top4 FrontEndLast,FrontEndDump,MidEndLast err-const-is-not-compile-time-known-value1.p4
err-const-is-not-compile-time-known-value1.p4(57): [--Werror=type-error] error: i: slice bit index values must be constants
            n[i:i] = 1;
              ^
```

I will ask the P4 language design work group if this is a program that
_should_ compile.  It seems to me like it should.


### Can loop variables be used as slice indexes?

#### v1, v2, v3

No.

```bash
$ mkdir -p tmp
$ p4test --dump tmp --top4 FrontEndLast,FrontEndDump,MidEndLast err-loop-var-cannot-be-used-in-slice1.p4
err-loop-var-cannot-be-used-in-slice1.p4(50): [--Werror=type-error] error: i: slice bit index values must be constants
            hdr.ethernet.srcAddr[i:i] = i[0:0];
                                 ^
```


### Can variables be used as slice indexes, at all?

#### v3

```bash
$ mkdir -p tmp
$ p4test --dump tmp --top4 FrontEndLast,FrontEndDump,MidEndLast err-var-is-not-compile-time-known-value1.p4
err-var-is-not-compile-time-known-value1.p4(75): [--Werror=type-error] error: i: slice bit index values must be constants
            n[i:i] = 1;
              ^
```

This issue asks whether variables should ever be considered
compile-time known values.  I would guess the answer will remain "no":

+ https://github.com/p4lang/p4-spec/issues/1291


### Is a loop variable with type declared in initialization clause in scope after loop body?

#### v1, v2, v3

No.  Good!

```bash
$ mkdir -p tmp
$ p4test --dump tmp --top4 FrontEndLast,FrontEndDump,MidEndLast err-loop-var-not-in-scope-outside-of-loop1.p4
err-loop-var-not-in-scope-outside-of-loop1.p4(53): [--Werror=not-found] error: i: declaration not found
        hdr.ethernet.srcAddr[7:0] = i;
                                    ^
```


### Is it allowed to have a for-in-range loop without a type declaration on the loop variable?

#### v3

No.  This was permitted in v1 and v2 implementations, but at 2024-Jul LDWG
meeting it was recommended that this be a compile-time error, and during
2024-Jul Chris Dodd modified p4c implementation so it is an error now.

There is an open issue for p4c as of 2024-Aug-03 to improve the compiler error message
for such programs:

+ https://github.com/p4lang/p4c/issues/4813

```bash
$ mkdir -p tmp
$ p4test --dump tmp --top4 FrontEndLast,FrontEndDump,MidEndLast err-loop-var-in-range-no-typeref1.p4
err-loop-var-in-range-no-typeref1.p4(51):syntax error, unexpected IN
        for (i in
               ^^
```
