# To run the test, add the bin directory to PATH
# and the DuroDBMS lib directory to LD_LIBRARY_PATH

import osproc
import duro
import unittest
import os

suite "table insert, update, delete":

  setup:
    let errC = execCmd("durodt update-setup.td")
    require(errC == 0)

  teardown:
    removeDir("dbenv")

  test "insertUpdate":
    let dc = createContext("dbenv", 0)
    require(dc != nil)

    let
      tx = dc.getDatabase("D").begin
      intup: tuple[n: int, s: string, f: float, b: bool,
                   bn: seq[byte]] = (n: 1, s: "Ui", f: 1.5, b: true, bn: @[byte(255)])
    duro.insert(t1, intup, tx)

    var
      outtup: tuple[n: int, s: string, f: float, b: bool, bn: seq[byte]]
    toTuple(outtup, tupleFrom(@@t1), tx)
    check(outtup.n == 1)
    check(outtup.s == "Ui")
    check(outtup.f == 1.5)
    check(outtup.b == true)
    check(outtup.bn == @[byte(255)])

    duro.update(t1, @@n $= 1, tx, s := toExpr("ohh"), f := toExpr(1.0), b := toExpr(false),
                 bn := toExpr(@[byte(1), byte(20)]))

    toTuple(outtup, tupleFrom(@@t1), tx)
    check(outtup.n == 1)
    check(outtup.s == "ohh")
    check(outtup.f == 1.0)
    check(outtup.b == false)
    check(outtup.bn == @[byte(1), byte(20)])

    tx.commit
    dc.closeContext

  test "delete":
    let dc = createContext("dbenv", 0)
    require(dc != nil)
  
    let
      tx = dc.getDatabase("D").begin
      intup: tuple[n: int, s: string, f: float, b: bool, bn: seq[byte]] = (n: 1, s: "Ui", f: 1.5, b: true, bn: @[byte(255)])
    duro.insert(t1, intup, tx)

    check(duro.delete(t1, @@n $= 1, tx) == 1)
    check(toInt(opInv("count", @@t1), tx) == 0)
    tx.commit
    dc.closeContext

  test "multiple assignment":
    let dc = createContext("dbenv", 0)
    require(dc != nil)
  
    let
      tx = dc.getDatabase("D").begin

    duro.insert(t2, (n: 1, m: 2), tx)
    duro.insert(t3, (n: 1, s: "Foo"), tx)
    duro.insert(t4, (n: 1, s: "Foo"), tx)
    duro.insert(t4, (n: 2, s: "Bar"), tx)

    check(assign(duro.insert(t1, (n: 1, s: "Ui", f: 1.5, b: true, bn: @[byte(255)])),
                 duro.update(t3, @@n $= 1, s := toExpr("Bar")),
                 duro.delete(t2, @@n $= 1),
                 duro.delete(t4, (n: 1, s: "Foo")),
                 tx) == 4)

    var
      outtup: tuple[n: int, s: string, f: float, b: bool, bn: seq[byte]]
    toTuple(outtup, tupleFrom(@@t1), tx)
    check(outtup.n == 1)
    check(outtup.s == "Ui")
    check(outtup.f == 1.5)
    check(outtup.b == true)
    check(outtup.bn == @[byte(255)])

    var
      outtup2: tuple[n: int, s: string]
    toTuple(outtup2, tupleFrom(@@t3), tx)
    check(outtup2.n == 1)
    check(outtup2.s == "Bar")

    check(toInt(count(@@t2), tx) == 0)

    check(toInt(count(@@t4), tx) == 1)
    toTuple(outtup2, tupleFrom(@@t4), tx)
    check(outtup2.n == 2)
    check(outtup2.s == "Bar")
    
    tx.commit
    dc.closeContext

  test "assigning table":
    let dc = createContext("dbenv", 0)
    require(dc != nil)

    let
      tx = dc.getDatabase("D").begin
    check(assign(t1 := @[(n: 1, s: "Uii", f: 1.5, b: true, bn: @[byte(255)]),
                         (n: 2, s: "yoyo", f: 2.0, b: false, bn: @[byte(0)])],
                 tx) == 1)

    check(toInt(count(@@t1), tx) == 2)

    var
      s: seq[tuple[n: int, s: string, f: float, b: bool, bn: seq[byte]]]
    load(s, @@t1, tx, SeqItem(attr: "n", dir: asc))
    check(s[0].n == 1)
    check(s[0].s == "Uii")
    check(s[0].f == 1.5)
    check(s[0].b == true)
    check(s[0].bn == @[byte(255)])
    check(s[1].n == 2)
    check(s[1].s == "yoyo")
    check(s[1].f == 2.0)
    check(s[1].b == false)
    check(s[1].bn == @[byte(0)])

    tx.commit
    dc.closeContext
