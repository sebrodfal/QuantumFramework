Package["Wolfram`QuantumFramework`"]

PackageExport["QuantumCircuitOperator"]

PackageScope["QuantumCircuitOperatorQ"]
PackageScope["BarrierQ"]
PackageScope["FromCircuitOperatorShorthand"]



BarrierQ[barrier_] := MatchQ[barrier, "Barrier" | "Barrier"[_ ? orderQ, ___] | "Barrier"[Span[_Integer, _Integer | All], ___]]

quantumCircuitOperatorQ[QuantumCircuitOperator[data_Association]] /; ! AtomQ[Unevaluated[data]] :=
    QuantumCircuitOperatorQ[QuantumCircuitOperator[data]]

quantumCircuitOperatorQ[QuantumCircuitOperator[KeyValuePattern[{"Elements" -> elements_, "Label" -> _}]]] :=
    AllTrue[elements,
        BarrierQ[#] ||
        QuantumFrameworkOperatorQ[#] &
    ]

QuantumCircuitOperatorQ[___] := False

QuantumCircuitOperatorQ[qco_QuantumCircuitOperator] := System`Private`HoldValidQ[qco]

QuantumCircuitOperatorQ[___] := False


qco_QuantumCircuitOperator /; quantumCircuitOperatorQ[Unevaluated[qco]] && ! System`Private`HoldValidQ[qco] := System`Private`HoldSetValid[qco]


Options[QuantumCircuitOperator] = {"Parameters" -> {}, "Label" -> None}

(* constructors *)

circuitNamePattern = name_String | {name_String, ___} | name_String[___] /; MemberQ[$QuantumCircuitOperatorNames, name]

FromCircuitOperatorShorthand[barrier_ ? BarrierQ] := barrier
FromCircuitOperatorShorthand[qc_ ? QuantumCircuitOperatorQ] := qc
FromCircuitOperatorShorthand[qc_ ? QuantumCircuitOperatorQ -> order_ ? orderQ] := QuantumCircuitOperator[qc, order]
FromCircuitOperatorShorthand[arg : circuitNamePattern] := QuantumCircuitOperator[arg]
FromCircuitOperatorShorthand[(arg : circuitNamePattern) -> args_] := QuantumCircuitOperator[FromCircuitOperatorShorthand[arg], args]
FromCircuitOperatorShorthand[(arg : circuitNamePattern) -> order_ ? orderQ -> args_] := QuantumCircuitOperator[FromCircuitOperatorShorthand[arg], order, args]
FromCircuitOperatorShorthand["M" | {"M", args___}] := FromCircuitOperatorShorthand[{"M", args} -> {1}]
FromCircuitOperatorShorthand["M" | {"M", args___} -> target_Integer] := FromCircuitOperatorShorthand[{"M", args} -> {target}]
FromCircuitOperatorShorthand["M" | {"M", args___} -> target_ ? orderQ] := QuantumMeasurementOperator[args, target]
FromCircuitOperatorShorthand[op : Except[_ ? QuantumCircuitOperatorQ, _ ? QuantumFrameworkOperatorQ]] := op
FromCircuitOperatorShorthand[arg_] := Enclose @ Replace[Confirm @ FromOperatorShorthand[arg], ops_List :> QuantumCircuitOperator[ops]]


QuantumCircuitOperator[operators_ ? ListQ] := Enclose @ With[{ops = Confirm @* FromCircuitOperatorShorthand /@ operators},
    QuantumCircuitOperator[<|"Elements" -> ops, "Label" -> Replace[RightComposition @@ (#["Label"] & /@ DeleteCases[ops, _ ? BarrierQ]), Identity -> "I"]|>]
]

QuantumCircuitOperator[arg_, order_ ? orderQ, args___] := QuantumCircuitOperator[QuantumCircuitOperator[arg, args], order]

QuantumCircuitOperator[arg_ -> order_ ? orderQ, args___] := QuantumCircuitOperator[QuantumCircuitOperator[arg, args], order]

QuantumCircuitOperator[operators_ ? ListQ, opts : OptionsPattern[]] := With[{label = OptionValue["Label"], parameters = OptionValue["Parameters"]},
    Enclose @ QuantumCircuitOperator[<|
        "Elements" -> (Confirm[If[parameters === {} || BarrierQ[#], #, Head[#][#, "Parameters" -> parameters]] & @ FromCircuitOperatorShorthand[#]] & /@ operators),
        "Label" -> label
    |>]
]


QuantumCircuitOperator[op : Except[_ ? QuantumCircuitOperatorQ | _ ? ListQ, _ ? QuantumFrameworkOperatorQ], args___] := QuantumCircuitOperator[{op}, args]

QuantumCircuitOperator[op_ ? QuantumCircuitOperatorQ, opts : OptionsPattern[]] := QuantumCircuitOperator[op["Elements"], opts, "Label" -> op["Label"]]

QuantumCircuitOperator[qco_ ? QuantumCircuitOperatorQ | {qco_ ? QuantumCircuitOperatorQ}] := qco

QuantumCircuitOperator[params: Except[{Alternatives @@ $QuantumCircuitOperatorNames, ___}, _List]] :=
    Enclose @ QuantumCircuitOperator[ConfirmBy[QuantumOperator[#], QuantumOperatorQ] & @@ Replace[#, param : Except[_List] :> {param}] & /@ params]

QuantumCircuitOperator[tn_ ? GraphQ, opts___] := FromTensorNetwork[tn, opts]

QuantumCircuitOperator[arg : Except[_List | _Association]] := QuantumCircuitOperator[{arg}]

QuantumCircuitOperator[operators_, label_, opts : OptionsPattern[]] := QuantumCircuitOperator[operators, "Label" -> label, opts]

QuantumCircuitOperator[] := QuantumCircuitOperator[{}]


(* composition *)

(qco_QuantumCircuitOperator ? QuantumCircuitOperatorQ)[op_ ? QuantumFrameworkOperatorQ] :=
    QuantumCircuitOperator[Prepend[qco["Elements"], op], qco["Label"][op["Label"]]]

Options[quantumCircuitApply] = {Method -> Automatic}

quantumCircuitApply[qco_QuantumCircuitOperator, qs_QuantumState, OptionsPattern[]] /; qco["InputDimensions"] == qs["OutputDimensions"][[# - Min[#] + 1 & @ qco["InputOrder"]]] := Replace[
    OptionValue[Method],
    {
        "Schrodinger" | "Schroedinger" | "Schrödinger" :> Fold[ReverseApplied[Construct], qs, qco["Operators"]],
        Automatic | "TensorNetwork" :> TensorNetworkApply[qco["Flatten"], qs],
        "QuEST" :> QuESTApply[qco, qs],
        "Qiskit" | {"Qiskit", opts___} :> qco["Qiskit"][qs, opts],
        "Stabilizer" :> PauliStabilizerApply[qco, qs],
        _ -> $Failed
    }
]

QuantumCircuitOperator::dim = "Circuit expecting dimensions `1`, but the state has dimensions `2`."

quantumCircuitApply[qco_QuantumCircuitOperator, qs_QuantumState, OptionsPattern[]] :=
    (Message[QuantumCircuitOperator::dim, qco["InputDimensions"], qs["OutputDimensions"]]; $Failed)


(qco_QuantumCircuitOperator ? QuantumCircuitOperatorQ)[qs_QuantumState ? QuantumStateQ, opts : OptionsPattern[quantumCircuitApply]] :=
    quantumCircuitApply[
        qco /* QuantumCircuitOperator[MapThread["I"[#1] -> #2 &, {qs["OutputDimensions"][[#]], #}] & @ Union[qco["FreeOrder"], Complement[Range[qs["OutputQudits"]], qco["InputOrder"]]]],
        If[# === {}, qs, QuantumTensorProduct[qs, QuantumState[{"Register", #}]]] & @
            ConstantArray[2, Max[0, Length[qco["FullInputOrder"]] - qs["OutputQudits"]]],
        opts
    ]

(qco_QuantumCircuitOperator ? QuantumCircuitOperatorQ)[opts : OptionsPattern[quantumCircuitApply]] := Switch[
    OptionValue[{opts}, Method],
    "Stabilizer",
    PauliStabilizerApply[qco, Automatic],
    "QuEST",
    QuESTApply[qco, QuantumState[{"Register", qco["InputDimensions"]}]],
    _,
    (QuantumCircuitOperator[MapThread[QuantumState["Register", #2, "Label" -> Ket[{"0"}]] -> {#1} &, {qco["InputOrder"], qco["InputDimensions"]}]] /* qco)[QuantumState[1, 1], opts]
]

(qco_QuantumCircuitOperator ? QuantumCircuitOperatorQ)[qm_QuantumMeasurement, opts : OptionsPattern[]] :=
    QuantumMeasurement[qco[qm["QuantumOperator"]]["QuantumOperator", opts]]

op_QuantumMeasurementOperator[qco_QuantumCircuitOperator ? QuantumCircuitOperatorQ] :=
    QuantumCircuitOperator[Append[qco["Elements"], op], op["Label"][qco["Label"]]]


QuantumCircuitOperator /: comp : Composition[___, _QuantumCircuitOperator ? QuantumCircuitOperatorQ, ___] := Enclose @
With[{ops = List @@ Unevaluated[comp]},
    QuantumCircuitOperator[Flatten[ConfirmBy[QuantumCircuitOperator[#], QuantumCircuitOperatorQ]["Elements"] & /@ Reverse @ ops, 1], Composition @@ (#["Label"] & /@ ops)]
]

QuantumCircuitOperator /: comp : RightComposition[___, _QuantumCircuitOperator ? QuantumCircuitOperatorQ, ___] := Enclose @
With[{ops = List @@ Unevaluated[comp]},
    QuantumCircuitOperator[Flatten[ConfirmBy[QuantumCircuitOperator[#], QuantumCircuitOperatorQ]["Elements"] & /@ ops, 1], RightComposition @@ Reverse @ (#["Label"] & /@ ops)]
]


(* dagger *)

SuperDagger[qco_QuantumCircuitOperator] ^:= qco["Dagger"]


(* equality *)

QuantumCircuitOperator /: Equal[left___, qco_QuantumCircuitOperator, right___] :=
    Equal @@ (If[QuantumCircuitOperatorQ[#], #["CircuitOperator"], #] & /@ {left, qco, right})


(* part *)

Part[qco_QuantumCircuitOperator, part_] ^:= QuantumCircuitOperator[qco["Elements"][[part]], qco["Label"]]


(* reorder *)

QuantumCircuitOperator[qc_ ? QuantumCircuitOperatorQ, order_ ? orderQ] := QuantumCircuitOperator[qc, {order, order}]

QuantumCircuitOperator[qc_ ? QuantumCircuitOperatorQ, order : {_ ? orderQ, _ ? orderQ}] := Block[{
    outOrder = Select[qc["OutputOrder"], Positive],
    inOrder = Select[qc["InputOrder"], Positive],
    outRepl, inRepl
},
    outRepl = Thread[outOrder -> Take[Join[order[[1]], Drop[outOrder, UpTo[Length[order[[1]]]]]], UpTo[Length[outOrder]]]];
    inRepl = Thread[inOrder -> Take[Join[order[[2]], Drop[inOrder, UpTo[Length[order[[2]]]]]], UpTo[Length[inOrder]]]];
    {outRepl, inRepl} = {Join[outRepl, inRepl], Join[inRepl, outRepl]};
    QuantumCircuitOperator[
        Which[
            BarrierQ[#], # /. inRepl,
            True, Head[#][#, {#["OutputOrder"] /. outRepl, #["InputOrder"] /. inRepl}]
        ] & /@ qc["Elements"],
        qc["Label"]
    ]
]

(* simplify *)

Simplify[qco_QuantumCircuitOperator, args___] ^:= qco["Simplify", args]

FullSimplify[qco_QuantumCircuitOperator, args___] ^:= qco["FullSimplify", args]

Chop[qco_QuantumCircuitOperator, args___] ^:= qco["Chop", args]


(* parameterization *)

(qco_QuantumCircuitOperator ? QuantumCircuitOperatorQ)[rules_ ? AssociationQ] :=
    QuantumCircuitOperator[
        If[BarrierQ[#] || #["ParameterArity"] == 0, #, #[KeyTake[rules, #["Parameters"]]]] & /@ qco["Elements"],
        qco["Label"] /. rules
    ] /; ContainsOnly[Keys[rules], qco["Parameters"]]

(qco_QuantumCircuitOperator ? QuantumCircuitOperatorQ)[parameters : PatternSequence[p : Except[_Association], ___]] /; ! MemberQ[QuantumCircuitOperator["Properties"], p] /; Length[{parameters}] <= Length[qco["Parameters"]] :=
    qco[AssociationThread[Take[qco["Parameters"], UpTo[Length[{parameters}]]], parameters]]

