Package["Wolfram`QuantumFramework`"]

PackageExport["QuantumState"]

PackageScope["QuantumStateQ"]


QuantumState::inState = "is invalid";

QuantumState::inBasis = "has invalid basis";

QuantumState::incompatible = "is incompatible with its basis";


QuantumStateQ[QuantumState[state_, basis_]] :=
    (stateQ[state] || (Message[QuantumState::inState]; False)) &&
    (QuantumBasisQ[basis] || (Message[QuantumState::inBasis]; False)) &&
    (Length[state] === basis["Dimension"] || (Message[QuantumState::incompatible]; False))

QuantumStateQ[___] := False


(* basis argument input *)

QuantumState[state_ ? stateQ, basisArgs___] /; !QuantumBasisQ[basisArgs] := Enclose @ Module[{
    basis, multiplicity
},
    basis = ConfirmBy[QuantumBasis[basisArgs], QuantumBasisQ];
    multiplicity = basisMultiplicity[Length[state], basis["Dimension"]];
    basis = ConfirmBy[QuantumBasis[basis, multiplicity], QuantumBasisQ];
    QuantumState[
        PadRight[state, Table[basis["Dimension"], TensorRank[state]]],
        basis
    ]
]


(* association input *)

QuantumState[state_ ? AssociationQ, basisArgs___] /; VectorQ[Values[state]] := Enclose @ Module[{
    basis = ConfirmBy[QuantumBasis[basisArgs], QuantumBasisQ], multiplicity},
    multiplicity = basisMultiplicity[Length[state], basis["Dimension"]];
    basis = ConfirmBy[QuantumBasis[basis, multiplicity], QuantumBasisQ];
    ConfirmAssert[ContainsOnly[QuditName /@ Keys[state], basis["ElementNames"]], "Association keys and basis names don't match"];
    QuantumState[
        Values @ KeyMap[QuditName, state][[Key /@ basis["ElementNames"]]] /. _Missing -> 0,
        basis
    ]
]


(* eigenvalues input *)

QuantumState["Eigenvalues" -> eigenvalues_ ? VectorQ, basisArgs___] := With[{
    basis = QuantumBasis[basisArgs]
},
    QuantumState[
        Total @ MapThread[#1 #2 &, {eigenvalues, basis["Projectors"]}],
        basis
    ] /; Length[eigenvalues] == basis["Dimension"]
]


(* expand basis *)

QuantumState[state_, args : Except[_ ? QuantumBasisQ]] := Enclose @ QuantumState[state, ConfirmBy[QuantumBasis[args], QuantumBasisQ]]

QuantumState[state_ ? stateQ, basis_ ? QuantumBasisQ] := QuantumState[
    state,
    QuantumTensorProduct[basis, QuantumBasis[Max[2, Length[state] - basis["Dimension"]]]]
] /; Length[state] > basis["Dimension"]


(* pad state *)

QuantumState[state_ ? stateQ, basis_ ? QuantumBasisQ] := QuantumState[
    PadRight[state, Table[basis["Dimension"], TensorRank[state]]],
    basis
] /; Length[state] < basis["Dimension"]


(* Mutation *)

QuantumState[state_ ? stateQ, basis_ ? QuantumBasisQ] /;
    ArrayQ[state, _ ? NumericQ] && Precision[state] === MachinePrecision && !Developer`PackedArrayQ[state] :=
    QuantumState[Developer`ToPackedArray[state], basis]


QuantumState[qs_ ? QuantumStateQ, args : Except[_ ? QuantumBasisQ, Except[Alternatives @@ $QuantumBasisPictures, _ ? nameQ]]] :=
    Enclose @ QuantumState[qs, ConfirmBy[QuantumBasis[args], QuantumBasisQ]]

QuantumState[qs_ ? QuantumStateQ, args : Except[_ ? QuantumBasisQ]] :=
    Enclose @ QuantumState[qs, ConfirmBy[QuantumBasis[qs["Basis"], args], QuantumBasisQ]]


(* change of basis *)

QuantumState[qs_ ? QuantumStateQ, newBasis_ ? QuantumBasisQ] /; ! newBasis["SortedQ"] := QuantumState[qs, newBasis["Sort"]]

QuantumState[qs_ ? QuantumStateQ, newBasis_ ? QuantumBasisQ] /; qs["Basis"] == newBasis := QuantumState[qs["State"], newBasis]

QuantumState[qs_ ? QuantumStateQ, newBasis_ ? QuantumBasisQ] /; qs["ElementDimension"] == newBasis["ElementDimension"] := Switch[
    qs["StateType"],
    "Vector",
    QuantumState[
        Flatten[
            PseudoInverse[newBasis["OutputMatrix"]] . (qs["OutputMatrix"] . qs["StateMatrix"] . PseudoInverse[qs["InputMatrix"]]) . newBasis["InputMatrix"]
        ],
        newBasis
    ],
    "Matrix",
    QuantumState[
        PseudoInverse[newBasis["Matrix"]] . (qs["Basis"]["Matrix"] . qs["DensityMatrix"] . PseudoInverse[qs["Basis"]["Matrix"]]) . newBasis["Matrix"],
        newBasis
    ]
]


(* renew basis *)

QuantumState[qs_ ? QuantumStateQ] := qs["Computational"]

(*QuantumState[qs_ ? QuantumStateQ, args__] := With[{
    newBasis = QuantumBasis[qs["Basis"], args]},
    If[ qs["Basis"] === newBasis,
        qs,
        QuantumState[qs["State"], newBasis]
    ]
]
*)

(* equality *)

QuantumState /: Equal[qs : _QuantumState ...] :=
    Equal @@ (#["Picture"] & /@ {qs}) && Equal @@ (#["NormalizedMatrixRepresentation"] & /@ {qs})

(* addition *)

QuantumState /: (qs1_QuantumState ? QuantumStateQ) + (qs2_QuantumState ? QuantumStateQ) /; qs1["Dimension"] == qs2["Dimension"] :=
    QuantumState[
        QuantumState[
            If[ qs1["StateType"] === qs2["StateType"] === "Vector",
                qs1["VectorRepresentation"] + qs2["VectorRepresentation"],
                qs1["MatrixRepresentation"] + qs2["MatrixRepresentation"]
            ],
            QuantumBasis[qs1["Dimensions"]]
        ],
        qs1["Basis"]
    ]

(* multiplication *)

QuantumState /: (qs1_QuantumState ? QuantumStateQ) * (qs2_QuantumState ? QuantumStateQ) /; qs1["Dimension"] == qs2["Dimension"] :=
    QuantumState[
        QuantumState[
            If[ qs1["StateType"] === qs2["StateType"] === "Vector",
                qs1["VectorRepresentation"] * qs2["VectorRepresentation"],
                qs1["MatrixRepresentation"] * ArrayReshape[qs2["MatrixRepresentation"], Dimensions @ qs1["MatrixRepresentation"]]
            ],
            QuantumBasis[qs1["Dimensions"]]
        ],
        qs1["Basis"]
    ]

QuantumState /: (x : (_ ? NumericQ) | _Symbol) * (qs_QuantumState ? QuantumStateQ) :=
    QuantumState[
        x qs["State"],
        qs["Basis"]
    ]

QuantumState /: (qs_QuantumState ? QuantumStateQ) ^ p_ := Enclose @ QuantumState[ConfirmBy[MatrixPower[qs["DensityMatrix"], p], MatrixQ], qs["Basis"]]

QuantumState /: f_Symbol[qs_QuantumState] /; MemberQ[Attributes[f], NumericFunction] :=
    Enclose @ QuantumState[ConfirmBy[MatrixFunction[f, qs["DensityMatrix"]], MatrixQ], qs["Basis"]]


(* composition *)

(qs1_QuantumState ? QuantumStateQ)[(qs2_QuantumState ? QuantumStateQ)] /; qs1["InputDimension"] == qs2["OutputDimension"] :=
    profile[StringTemplate["State composition: `` -> ``"][qs1["Dimensions"], qs2["Dimensions"]]] @ QuantumState[
        QuantumState[
            profile["Matrix multiply"] @ Flatten[qs1["PureMatrix"] . qs2["PureMatrix"]],
            QuantumBasis["Output" -> QuditBasis[qs1["OutputDimensions"]], "Input" -> QuditBasis[qs2["InputDimensions"]]]
        ],
        QuantumBasis["Output" -> qs1["Output"], "Input" -> qs2["Input"], "Label" -> qs1["Label"] @* qs2["Label"]]
    ]
