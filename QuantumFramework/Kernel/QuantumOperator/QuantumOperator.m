Package["Wolfram`QuantumFramework`"]

PackageExport["QuantumOperator"]

PackageScope["QuantumOperatorQ"]
PackageScope["StackQuantumOperators"]


QuantumOperator::invalidInputOrder = "input order should be a list of distinct input qudit positions"
QuantumOperator::invalidOutputOrder = "output order should be a list of distinct output qudit positions"

quantumOperatorQ[QuantumOperator[qs_, {outputOrder_ ? orderQ, inputOrder_ ? orderQ}]] :=
    QuantumStateQ[qs] &&
    (orderQ[outputOrder] || (Message[QuantumOperator::invalidOutputOrder]; False)) &&
    (orderQ[inputOrder] || (Message[QuantumOperator::invalidInputOrder]; False))


quantumOperatorQ[___] := False


QuantumOperatorQ[qo_QuantumOperator] := System`Private`HoldValidQ[qo]

QuantumOperatorQ[___] := False


qo_QuantumOperator /; quantumOperatorQ[Unevaluated[qo]] && ! System`Private`HoldValidQ[qo] := System`Private`HoldSetValid[qo]


(* constructors *)

SetAttributes[QuantumOperator, NHoldRest]

QuantumOperator[arg : _ ? QuantumStateQ, order : {_ ? orderQ, _ ? orderQ}, opts__] :=
    Enclose @ QuantumOperator[ConfirmBy[QuantumState[arg, opts], QuantumStateQ], order]

QuantumOperator[qs_ ? QuantumStateQ, order : {outputOrder_ ? orderQ, inputOrder_ ? orderQ}] /;
    qs["Qudits"] == Length[outputOrder] + Length[inputOrder] && (qs["OutputQudits"] != Length[outputOrder] || qs["InputQudits"] != Length[inputOrder]) :=
    QuantumOperator[qs["SplitDual", Length[outputOrder]], order]

QuantumOperator[qs_ ? QuantumStateQ] :=
    QuantumOperator[
        qs,
        If[qs["InputDimension"] > 1, {Automatic, Range[qs["InputQudits"]]}, {Range[qs["OutputQudits"]], Automatic}]
    ]

QuantumOperator[arg : _ ? QuantumStateQ, outputOrder : _ ? orderQ | Automatic, inputOrder : _ ? orderQ | Automatic, opts___] :=
    QuantumOperator[QuantumState[arg, opts], {outputOrder, inputOrder}]

QuantumOperator[qs : _ ? QuantumStateQ, order : _ ? orderQ | Automatic, opts___] :=
    QuantumOperator[qs, {Replace[order, Automatic :> Range[qs["OutputQudits"]]], Automatic}, opts]


QuantumOperator[qs_ ? QuantumStateQ, {Automatic, order_ ? orderQ}, opts___] :=
    QuantumOperator[
        qs,
        {
            Reverse @ Take[Join[Reverse @ order, Min[order] - Range[Max[1, qs["OutputQudits"] - qs["InputQudits"]]]], UpTo @ qs["OutputQudits"]],
            order
        },
        opts
    ]

QuantumOperator[qs_ ? QuantumStateQ, {order_ ? orderQ, Automatic}, opts___] :=
    QuantumOperator[
        qs,
        {
            order,
            Reverse @ Take[Join[Reverse @ order, Min[order] - Range[Max[1, qs["InputQudits"] - qs["OutputQudits"]]]], UpTo @ qs["InputQudits"]]
        },
        opts
    ]

QuantumOperator[qs_ ? QuantumStateQ, opts : PatternSequence[Except[{_ ? orderQ, _ ? orderQ}], ___]] := QuantumOperator[
    QuantumOperator[qs],
    QuantumBasis[qs["Basis"], opts]
]

QuantumOperator[qs_ ? QuantumStateQ, {outputOrder_ ? orderQ, inputOrder_}] /; qs["OutputDimension"] == 1 && Length[outputOrder] > 0 :=
    QuantumOperator[qs, {{}, inputOrder}]

QuantumOperator[qs_ ? QuantumStateQ, {outputOrder_, inputOrder_ ? orderQ}] /; qs["InputDimension"] == 1 && Length[inputOrder] > 0 :=
    QuantumOperator[qs, {outputOrder, {}}]

QuantumOperator[tensor_ ? TensorQ /; TensorRank[tensor] > 2, order : _ ? autoOrderQ : Automatic, args___, opts : OptionsPattern[]] := Block[{
    dimensions = TensorDimensions[tensor],
    outputOrder,
    basis,
    inputDimension, outputDimension
},
    basis = QuantumBasis[args];
    If[ Times @@ dimensions === basis["Dimension"],
        dimensions = basis["Dimensions"]
    ];
    outputOrder = Replace[order, {
        Automatic :> Range[Min[basis["OutputQudits"], Length[dimensions]]],
        {o_ ? orderQ, _} :> o,
        {Automatic, o_ ? orderQ} :> Range[Max[Length[dimensions] - Length[o], 0]]}
    ];
    {outputDimension, inputDimension} = Times @@@ TakeDrop[dimensions, Length[outputOrder]];
    If[ basis["OutputDimension"] != outputDimension,
        basis = QuantumBasis[basis, "Output" -> QuditBasis[dimensions[[;; Length[outputOrder]]]]]
    ];
    If[ basis["InputDimension"] != inputDimension,
        basis = QuantumBasis[basis, "Input" -> QuditBasis[dimensions[[Length[outputOrder] + 1 ;;]]]["Dual"]]
    ];
    QuantumOperator[
        ArrayReshape[tensor, {outputDimension, inputDimension}],
        order,
        basis,
        opts
    ]
]

QuantumOperator[assoc_Association, order : (_ ? orderQ) : {1}, args___, opts : OptionsPattern[]] := Enclose @ Module[{
    quditBasis,
    basis,
    tensorDimensions
},
    quditBasis = QuditBasis[
        Association @ Catenate @ MapIndexed[
            With[{counts = #1, i = First[#2]}, MapIndexed[{QuditName[#1], i} -> UnitVector[Length[counts], First[#2]] &, Keys @ counts]] &,
            Counts /@ Transpose[ConfirmBy[List @@@ Keys[assoc], MatrixQ]]
        ],
        args
    ];
    ConfirmAssert[Length[assoc] > 0 && Equal @@ TensorDimensions /@ assoc];
    ConfirmAssert[EvenQ @ quditBasis["Qudits"]];
    basis = QuantumBasis[
        "Output" -> QuantumPartialTrace[quditBasis, Range[quditBasis["Qudits"] / 2 + 1, quditBasis["Qudits"]]],
        "Input" -> QuantumPartialTrace[quditBasis, Range[quditBasis["Qudits"] / 2]]["Dual"]
    ];
    tensorDimensions = TensorDimensions @ First[assoc];
    QuantumOperator[
        ArrayReshape[Lookup[KeyMap[QuditName[List @@ #] &, assoc], quditBasis["Names"], 0], Join[basis["Dimensions"], tensorDimensions]],
        Join[Complement[Range[Length[tensorDimensions]], order], order],
        basis,
        opts
    ]
]


QuantumOperator::invalidState = "invalid state specification";


QuantumOperator[matrix_ ? MatrixQ, order : _ ? autoOrderQ, args___, opts : OptionsPattern[]] := Enclose @ Module[{
    op = ConfirmBy[QuantumOperator[matrix, args], QuantumOperatorQ],
    newOutputOrder, newInputOrder
},
    {newOutputOrder, newInputOrder} = Replace[order, {
        out_ ? orderQ /; Length[out] == op["InputQudits"] :> {out, out},
        out_ ? orderQ :> {out, op["InputOrder"]},
        Automatic :> op["Order"],
        {out : _ ? orderQ | Automatic, in : _ ? orderQ | Automatic} :> {Replace[out, Automatic :> op["OutputOrder"]], Replace[in, Automatic :> op["InputOrder"]]}
    }];
    QuantumOperator[op["State"]["Split", Length[newOutputOrder]], {newOutputOrder, newInputOrder}, opts]
]

QuantumOperator[matrix_ ? MatrixQ, args___, opts : OptionsPattern[]] := Module[{
    outMultiplicity, inMultiplicity, result
},
    result = Enclose @ Module[{newMatrix = matrix, outputs, inputs,
        basis, newOutputQuditBasis, newInputQuditBasis, state},
        {outputs, inputs} = Dimensions[newMatrix];
        basis = ConfirmBy[QuantumBasis[args], QuantumBasisQ, "Invalid basis"];
        If[ basis["Dimension"] =!= outputs * inputs,
            If[ basis["InputDimension"] == 1,
                basis = QuantumBasis[basis, "Input" -> basis["Output"]["Dual"]]
            ];
            outMultiplicity = Quiet @ Log[basis["OutputDimension"], outputs];
            inMultiplicity = Quiet @ Log[basis["InputDimension"], inputs];
            If[
                IntegerQ[outMultiplicity] && IntegerQ[inMultiplicity],
                (* multiply existing basis *)

                basis = QuantumBasis[basis,
                    "Output" -> QuditBasis[basis["Output"], outMultiplicity],
                    "Input" -> QuditBasis[basis["Input"], inMultiplicity]
                ],

                (* add one extra qudit *)
                newOutputQuditBasis = QuantumTensorProduct[basis["Output"], QuditBasis[Ceiling[outputs / basis["OutputDimension"]] /. 1 -> Sequence[]]];
                newInputQuditBasis = QuantumTensorProduct[basis["Input"], QuditBasis[Ceiling[inputs / basis["InputDimension"]] /. 1 -> Sequence[]]];

                newMatrix = kroneckerProduct[
                    newMatrix,
                    With[{outs = Ceiling[newOutputQuditBasis["Dimension"] / outputs], ins = Ceiling[newInputQuditBasis["Dimension"] / inputs]},
                        Replace[{} -> {{1}}] @ identityMatrix[Max[outs, ins]][[;; outs, ;; ins]]
                    ]
                ];
                basis = QuantumBasis[basis,
                    "Output" -> newOutputQuditBasis,
                    "Input" -> If[newInputQuditBasis["DualQ"], newInputQuditBasis, newInputQuditBasis["Dual"]]
                ];
            ]
        ];
        state = ConfirmBy[
            QuantumState[
                Flatten[newMatrix],
                basis
            ],
            QuantumStateQ,
            Message[QuantumOperator::invalidState]
        ];
        QuantumOperator[state, {Range[basis["FullOutputQudits"]], Range[basis["FullInputQudits"]]}, opts]
    ];
    result /; !FailureQ[Unevaluated @ result]
]

QuantumOperator[array_ ? NumericArrayQ, args___] := QuantumOperator[Normal @ array, args]


QuantumOperator[n_Integer, args___] := QuantumOperator[{"PhaseShift", n}, args]


QuantumOperator[Labeled[arg_, label_], opts___] := QuantumOperator[arg, opts, "Label" -> label]

QuantumOperator[{}, opts___] := QuantumOperator[QuantumState[{}, 0], opts]

QuantumOperator[arg_List, opts___] := QuantumOperator[QuantumState[Flatten[arg]], opts]

QuantumOperator[arg_, order1 : _ ? orderQ -> order2 : _ ? orderQ, opts___] :=
    QuantumOperator[arg, {order2, order1}, opts]


(* Mutation *)

QuantumOperator[qo_ ? QuantumOperatorQ, order : (_ ? orderQ | Automatic)] :=
    QuantumOperator[qo, {order, order}]

QuantumOperator[qo_ ? QuantumOperatorQ, outputOrder : (_ ? orderQ | Automatic), inputOrder : (_ ? orderQ | Automatic)] :=
    QuantumOperator[qo, {outputOrder, inputOrder}]

QuantumOperator[qo_ ? QuantumOperatorQ, order : {order1 : _ ? orderQ | Automatic, order2 : _ ? orderQ | Automatic}, opts : OptionsPattern[]] := Block[{
    outputOrder = Replace[order1, Automatic -> qo["OutputOrder"]],
    inputOrder = Replace[order2, Automatic -> qo["InputOrder"]],
    outputQudits = Max[qo["FullOutputQudits"], 1],
    inputQudits = Max[qo["FullInputQudits"], 1]
},
    QuantumOperator[
        {qo, LCM[Quotient[Length[outputOrder], outputQudits], Quotient[Length[inputOrder], inputQudits]]},
        {outputOrder, inputOrder},
        opts
     ] /;
        Length[outputOrder] > outputQudits && Divisible[Length[outputOrder], outputQudits] &&
        Length[inputOrder] > inputQudits && Divisible[Length[inputOrder], inputQudits]
]


QuantumOperator[qo_ ? QuantumOperatorQ, order : {_ ? orderQ | Automatic, _ ? orderQ | Automatic}] := qo["Reorder", order, True]

QuantumOperator[qo_ ? QuantumOperatorQ, order1 : _ ? orderQ | Automatic -> order2 : _ ? orderQ | Automatic, opts___] :=
    QuantumOperator[qo, {order2, order1}, opts]

QuantumOperator[qo_ ? QuantumOperatorQ, opts : PatternSequence[Except[_ ? QuantumBasisQ], ___],
    outputOrder : (_ ? orderQ | Automatic), inputOrder : (_ ? orderQ | Automatic)] := Enclose @
    QuantumOperator[qo, {outputOrder, inputOrder}, ConfirmBy[QuantumBasis[qo["Basis"], opts], QuantumBasisQ]]

QuantumOperator[qo_ ? QuantumOperatorQ, order : (_ ? orderQ | Automatic), opts : PatternSequence[Except[_ ? QuantumBasisQ], ___]] := Enclose @
    QuantumOperator[qo, {order, order}, ConfirmBy[QuantumBasis[qo["Basis"], opts], QuantumBasisQ]]

QuantumOperator[qo_ ? QuantumOperatorQ, order : _ ? autoOrderQ, opts : PatternSequence[Except[_ ? QuantumBasisQ], ___]] := Enclose @
    QuantumOperator[qo, order, ConfirmBy[QuantumBasis[qo["Basis"], opts], QuantumBasisQ]]

QuantumOperator[qo_ ? QuantumOperatorQ, opts : PatternSequence[Except[_ ? autoOrderQ | _ ? QuantumBasisQ | _ ? QuantumOperatorQ], ___]] := Enclose @
    QuantumOperator[qo, qo["Order"], ConfirmBy[QuantumBasis[qo["Basis"], opts], QuantumBasisQ]]

QuantumOperator[{qo : _ ? QuantumOperatorQ, multiplicity_Integer ? Positive}] := QuantumOperator[{qo, multiplicity}, Range[multiplicity]]

QuantumOperator[{qo : _ ? QuantumOperatorQ, multiplicity_Integer ? Positive}, opts__] :=
    QuantumOperator[QuantumTensorProduct @ Table[qo, multiplicity], opts]

QuantumOperator[qc_ ? QuantumCircuitOperatorQ, opts___] := QuantumOperator[qc["QuantumOperator"], opts]

QuantumOperator[q : _ ? QuantumChannelQ | _ ? QuantumMeasurementOperatorQ | _ ? QuantumMeasurementQ, opts___] := QuantumOperator[q["Operator"], opts]

QuantumOperator[x : Except[_ ? QuantumStateQ | _ ? QuantumOperatorQ | _ ? QuantumCircuitOperatorQ], args___] := Enclose @
    ConfirmBy[QuantumOperator[{"Diagonal", If[AtomQ[x], x, HoldForm[x]]}, args], QuantumOperatorQ]


(* change of basis *)

QuantumOperator[qo_ ? QuantumOperatorQ, name_ ? nameQ, opts___] := QuantumOperator[qo, QuantumBasis[name], opts]

QuantumOperator[qo_ ? QuantumOperatorQ, qb_ ? QuantumBasisQ, opts___] := QuantumOperator[qo, qo["Order"], qb, opts]

QuantumOperator[qo_ ? QuantumOperatorQ, order : _ ? autoOrderQ, qb_ ? QuantumBasisQ, opts___] :=
Enclose @ Block[{
    newBasis
},
    newBasis = If[
        qb["InputDimension"] == 1 && qo["InputDimension"] > 1,
        QuantumBasis[qb, "Input" -> qb["Output"]["Dual"]],
        QuantumBasis[qb]
    ];

    newBasis = QuantumBasis[qb,
        "Output" -> Confirm @ QuditBasis[qo["Output"], newBasis["Output"]],
        "Input" -> Confirm @ QuditBasis[qo["Input"], newBasis["Input"]],
        opts
    ];

    ConfirmAssert[qo["Dimension"] == newBasis["Dimension"], "Basis dimensions are inconsistent"];
    QuantumOperator[
        ConfirmBy[
            QuantumState[
                qo["State"],
                newBasis
            ],
            QuantumStateQ,
            Message[QuantumOperator::invalidState]
        ],
        order
    ]
]

QuantumOperator[qo_ ? QuantumOperatorQ,
    outputOrder : _ ? orderQ | Automatic : Automatic, inputOrder : _ ? orderQ | Automatic : Automatic, qb_ ? QuantumBasisQ, opts___] :=
    QuantumOperator[qo, {outputOrder, inputOrder}, qb, opts]

(* composition *)

(qo_QuantumOperator ? QuantumOperatorQ)[qb_ ? QuantumBasisQ] := QuantumBasis[
    AssociationThread[qo["Output"]["Names"], qo[#]["StateVector"] & /@ qb["BasisStates"]],
    "Label" -> qo["Label"] @* qb["Label"],
    qb["Meta"]
]

QuantumOperator::incompatiblePictures = "Pictures `` and `` are incompatible with this operation"

(qo_QuantumOperator ? QuantumOperatorQ)[qs_ ? QuantumStateQ] :=
Enclose @ Block[{
    order = Range[Max[1, qs["OutputQudits"]]] + Max[0, Max[qo["InputOrder"]] - qs["OutputQudits"]], res
},
    res = ConfirmBy[qo[QuantumOperator[qs, order, Automatic]], QuantumOperatorQ]["Sort"]["State"];
    If[qs["MatrixQ"], res["Unbend"], res]
]


(qo1_QuantumOperator ? QuantumOperatorQ)[qo2_ ? QuantumOperatorQ] := Enclose @ Block[{
    top = qo1["Sort"], bot = qo2["Sort"],
    fullTopOut, fullBotIn, fullTopIn, fullBotOut, topOut, botIn, out, in, basis, tensor
},
    fullTopOut = 1 /@ top["FullOutputOrder"];
    fullTopIn = If[MemberQ[bot["OutputOrder"], #], 0, 2][#] & /@ top["FullInputOrder"];
    fullBotOut = If[MemberQ[top["InputOrder"], #], 0, 1][#] & /@ bot["FullOutputOrder"];
    fullBotIn = 2 /@ bot["FullInputOrder"];
    topOut = Join[
        DeleteElements[fullTopOut, 1 /@ Complement[top["FullOutputOrder"], top["OutputOrder"]]],
        Cases[2 /@ DeleteElements[top["OutputOrder"], top["FullOutputOrder"]], Alternatives @@ fullBotIn]
    ];
    botIn = Join[
        DeleteElements[fullBotIn, 2 /@ Complement[bot["FullInputOrder"], bot["InputOrder"]]],
        Cases[1 /@ DeleteElements[bot["InputOrder"], bot["FullInputOrder"]], Alternatives @@ fullTopOut]
    ];
    out = Join[topOut, Cases[fullBotOut, 1[_]]];
    in = Join[Cases[fullTopIn, 2[_]], botIn];
    With[{
        outBasis = Join[top["Output"]["Decompose"], bot["Output"]["Decompose"]],
        inBasis = Join[top["Input"]["Decompose"], bot["Input"]["Decompose"]],
        outIndex = First /@ PositionIndex[Join[fullTopOut, fullBotOut]],
        inIndex = First /@ PositionIndex[Join[fullTopIn, fullBotIn]]
    },
        basis = QuantumBasis[
            QuantumBasis[
                QuantumTensorProduct @ Replace[
                    Join[out, in], {
                        i : 1[_] :> outBasis[[outIndex[i]]],
                        i : 2[_] :> inBasis[[inIndex[i]]]
                    },
                    {1}
                ]
            ]["Split", Length[out]],
            "Picture" -> If[MemberQ[{top["Picture"], bot["Picture"]}, "PhaseSpace"], "PhaseSpace", top["Picture"]],
            "Label" -> top["Label"] @* bot["Label"],
            "ParameterSpec" -> MergeParameterSpecs[top, bot]
        ]
    ];
    tensor = Confirm[
        If[
            top["VectorQ"] && bot["VectorQ"],
            SparseArrayFlatten @ EinsteinSummation[
                {Join[fullTopOut, fullTopIn], Join[fullBotOut, fullBotIn]} -> Join[out, in],
                {top["TensorRepresentation"], bot["TensorRepresentation"]}
            ],
            ArrayReshape[
                EinsteinSummation[
                    {Join[fullTopOut, 3 @@@ fullTopOut, fullTopIn, 4 @@@ fullTopIn], Join[fullBotOut, 4 @@@ fullBotOut, fullBotIn, 3 @@@ fullBotIn]} ->
                        Join[out, in, Join[3 @@@ topOut, 4 @@@ Cases[fullBotOut, 1[_]]], Join[4 @@@ Cases[fullTopIn, 2[_]], 3 @@@ botIn]],
                    {If[top["VectorQ"], top["Computational"]["State"]["Bend"], top]["TensorRepresentation"], If[bot["VectorQ"], bot["Computational"]["State"]["Bend"], bot]["TensorRepresentation"]}
                ],
                Table[basis["Dimension"], 2]
            ]
        ]
    ];
    QuantumOperator[
        QuantumState[
            QuantumState[
                tensor,
                QuantumBasis[basis["OutputDimensions"], basis["InputDimensions"]]
            ],
            basis
        ],
        orderDuplicates /@ Map[First, {out, in}, {2}]
    ]
]

orderDuplicates[xs_List] := Block[{next = Function[{ys, y}, If[MemberQ[ys, y], next[ys, y + 1], y]]}, Fold[Append[#1, next[#1, #2]] &, {}, xs]]


(qo_QuantumOperator ? QuantumOperatorQ)[qmo_ ? QuantumMeasurementOperatorQ] /; qo["Picture"] == qmo["Picture"] :=
    QuantumMeasurementOperator[qo @ qmo["SuperOperator"], qmo["Target"]]

(qo_QuantumOperator ? QuantumOperatorQ)[qm_ ? QuantumMeasurementQ] /; qo["Picture"] == qm["Picture"] :=
    If[QuantumMeasurementOperatorQ[#], QuantumMeasurement[#["Sort"]], #] & @ qo[qm["QuantumOperator"]]

(qo_QuantumOperator ? QuantumOperatorQ)[qco_QuantumCircuitOperator ? QuantumCircuitOperatorQ] :=
    QuantumCircuitOperator[Append[qco["Operators"], qo]]


expandQuditBasis[qb_QuditBasis, order1_ ? orderQ, order2_ ? orderQ, defaultDim_Integer : 2] := Enclose @ (
    ConfirmAssert[Length[order1] == qb["Qudits"]];
    QuantumTensorProduct[order2 /. Append[Thread[order1 -> qb["Decompose"]], _Integer -> QuditBasis[defaultDim]]]
)

matrixFunction[f_, mat_] := Enclose[Quiet @ ConfirmBy[MatrixFunction[f, mat, Method -> "Jordan"], MatrixQ], MatrixFunction[f, mat] &]

QuantumOperator /: HoldPattern[Plus[x : Except[_QuantumOperator], qo_QuantumOperator]] /; NumericQ[Unevaluated[x]] := With[{op = qo["Sort"]},
    QuantumOperator[
        Plus[DiagonalMatrix[ConstantArray[x, Min[op["MatrixNameDimensions"]], SparseArray], 0, op["MatrixNameDimensions"]], op["Matrix"]],
        op["Order"],
        op["Basis"],
        "Label" -> x + op["Label"]
    ]
]

QuantumOperator /: f_Symbol[left : Except[_QuantumOperator] ..., qo_QuantumOperator, right : Except[_QuantumOperator] ...] /; MemberQ[Attributes[f], NumericFunction] := With[{op = qo["Sort"]},
    Enclose @ QuantumOperator[
        ConfirmBy[
            If[MemberQ[{Minus, Times}, f], f[left, #, right] &, matrixFunction[f[left, #, right] &, #] &] @ op["Matrix"],
            MatrixQ
        ],
        op["Order"], op["Basis"], "Label" -> f[left, op["Label"], right]
    ]
]


QuantumOperator /: Plus[ops : _QuantumOperator...] := Fold[addQuantumOperators, {ops}]

addQuantumOperators[qo1_QuantumOperator ? QuantumOperatorQ, qo2_QuantumOperator ? QuantumOperatorQ] := Enclose @ Module[{
    orderInput, orderOutput,
    ordered1, ordered2
},
    orderInput = Sequence @@ With[{
            order = Union[qo1["InputOrder"], qo2["InputOrder"]],
            qbMap = Association[Thread[qo1["InputOrder"] -> qo1["Input"]["Decompose"]], Thread[qo2["InputOrder"] -> qo2["Input"]["Decompose"]]]
        },
            {"OrderedInput", order, QuantumTensorProduct[order /. qbMap]}
    ];
    orderOutput = Sequence @@ With[{
            order = Union[qo1["OutputOrder"], qo2["OutputOrder"]],
            qbMap = Association[Thread[qo1["OutputOrder"] -> qo1["Output"]["Decompose"]], Thread[qo2["OutputOrder"] -> qo2["Output"]["Decompose"]]]
        },
            {"OrderedOutput", order, QuantumTensorProduct[order /. qbMap]}
    ];
    ordered1 = qo1[orderInput]["Sort"][orderOutput]["Sort"];
    ordered2 = qo2[orderInput]["Sort"][orderOutput]["Sort"];
    ConfirmAssert[ordered1["Dimensions"] == ordered2["Dimensions"]];
    QuantumOperator[
        QuantumOperator[
            ordered1["MatrixRepresentation"] + ordered2["MatrixRepresentation"],
            QuantumBasis[ordered1["OutputDimensions"], ordered2["InputDimensions"]]
        ],
        ordered1["Order"],
        QuantumBasis[
            ordered1["Basis"],
            "Label" -> ordered1["Label"] + ordered2["Label"],
            "ParameterSpec" -> MergeParameterSpecs[ordered1, ordered2]
        ]
    ]
]


(* differentiation *)

QuantumOperator /: D[op : _QuantumOperator, args___] := QuantumOperator[D[op["State"], args], op["Order"]]


(* dagger *)

SuperDagger[qo_QuantumOperator] ^:= qo["Dagger"]


(* simplify *)

Simplify[qo_QuantumOperator, args___] ^:= qo["Simplify", args]

FullSimplify[qo_QuantumOperator, args___] ^:= qo["FullSimplify", args]

Chop[qo_QuantumOperator, args___] ^:= qo["Chop", args]


(* join *)

QuantumOperator[qo_ ? QuantumOperatorQ] := qo

QuantumOperator[qo__QuantumOperator ? QuantumOperatorQ] := QuantumOperator[{"Multiplexer", qo}]


(* equality *)

QuantumOperator /: Equal[qo : _QuantumOperator ... ] :=
    Equal @@ (#["Picture"] & /@ {qo}) && And @@ Thread[Equal @@ (Chop @ SetPrecisionNumeric @ SparseArrayFlatten @ #["Sort"]["MatrixRepresentation"] & /@ {qo})]


(* conversion *)

QuantumOperator[obj : _QuantumMeasurementOperator | _QuantumMeasurement | _QuantumChannel | _QuantumCircuitOperator, opts___] :=
    QuantumOperator[obj["QuantumOperator"], opts]


(* parameterization *)

(qo_QuantumOperator ? QuantumOperatorQ)[] := qo[QuantumState[{"Register", qo["InputDimensions"]}]]

(qo_QuantumOperator ? QuantumOperatorQ)[ps__] /; Length[{ps}] <= qo["ParameterArity"] :=
    QuantumOperator[qo["State"][ps], qo["Order"]]


StackQuantumOperators[ops : {_ ? QuantumOperatorQ ..}, name_ : "E"] := Block[{
    basis = First[ops]["Basis"],
    order = MapAt[Prepend[#, Min[#] - 1] &, First[ops]["Order"], {1}]
},
    basis = QuantumBasis[basis,
        "Output" -> QuantumTensorProduct[QuditBasis[Subscript[name, #] & /@ Range @ Length @ ops], basis["Output"]],
        "Input" -> basis["Input"]
    ];
    QuantumOperator[
        QuantumOperator[
            SparseArray[#["MatrixRepresentation"] & /@ ops],
            QuantumBasis[basis["OutputDimensions"], basis["InputDimensions"]]
        ],
        order,
        basis
    ]
]
