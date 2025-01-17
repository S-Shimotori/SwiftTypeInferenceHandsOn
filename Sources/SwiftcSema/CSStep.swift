import SwiftcBasic
import SwiftcType
import SwiftcAST

extension ConstraintSystem {
    public struct StepState {
        public var bindings: TypeVariableBindings
        public var astTypes: [AnyASTNode: Type]
        public var overloadSelections: [AnyASTNode: OverloadSelection]
        public var typeConversionRelations: [TypeConversionRelation]
        public var failedConstraint: ConstraintEntry?
        public var constraints: [ConstraintEntry]
    }
    
    /// Returns the current state of step.
    public func storeStepState() -> StepState {
        return StepState(bindings: bindings,
                         astTypes: astTypes,
                         overloadSelections: overloadSelections,
                         typeConversionRelations: typeConversionRelations,
                         failedConstraint: failedConstraint,
                         constraints: constraints)
    }
    
    /// Loads a given state of step.
    public func loadStepState(_ s: StepState) {
        self.bindings = s.bindings
        self.astTypes = s.astTypes
        self.overloadSelections = s.overloadSelections
        self.typeConversionRelations = s.typeConversionRelations
        self.failedConstraint = s.failedConstraint
        self.constraints = s.constraints
    }
    
    /// `ComponentStep` represents a set of type variables and related constraints which could be solved independently.
    /// It's further simplified into "binding" steps which attempt type variable and disjunction choices. \
    /// ref: ComponentStep at [CSStep.cpp](https://github.com/apple/swift/blob/main/lib/Sema/CSStep.cpp)
    public struct ComponentStep {
        public let work: SolveWork
        private let cts: ConstraintSystem
        private let pr: Printer
        public init(work: SolveWork) {
            self.work = work
            self.cts = work.cts
            self.pr = work.cts.printer
        }
        
        public func run() -> Bool {
            pr.goToLineHead()
            pr.println("(componentStep")
            pr.push()
            defer {
                pr.pop()
                pr.print(")")
            }
            
            guard _run() else {
                pr.goToLineHead()
                pr.print("no solution")
                return false
            }
           
            return true
        }
        
        // ref: take at CSStep.cpp
        private func _run() -> Bool {
            guard cts.simplify() else {
                return false
            }
            
            let bestBindingsOrNone = cts.determineBestBindings()
            let disjunctionOrNone = cts.selectDisjunction()
            
            // consider priority for bindings and disjunctions
            
            // <Q10 hint="invoke substeps" />
            if let disjunction = disjunctionOrNone {
                return DisjunctionStep(work: work, disjunction: disjunction).run()
            }
            if let potentialBindings = bestBindingsOrNone {
                return TypeVariableStep(work: work, bindings: potentialBindings).run()
            }
            
            if cts.hasFreeTypeVariables() {
                return false
            }
            
            pr.goToLineHead()
            pr.print("found solution")
            let solution = cts.formSolution()
            work.solutions.append(solution)
            return true
        }
    }

    private func selectDisjunction() -> ConstraintEntry? {
        return constraints.first { $0.constraint.kind == .disjunction }
    }
    
    // generalize this and DisjunctionStep
    public struct TypeVariableStep {
        public let work: SolveWork
        private let cts: ConstraintSystem
        private let pr: Printer
        public let bindings: PotentialBindings
        public init(work: SolveWork,
                    bindings: PotentialBindings)
        {
            self.work = work
            self.cts = work.cts
            self.pr = work.cts.printer
            self.bindings = bindings
        }
        
        public func run() -> Bool {
            pr.goToLineHead()
            pr.println("(typeVariableStep")
            pr.push()
            defer {
                pr.pop()
                pr.print(")")
            }
            
            var isAnySolved = false
            
            for binding in bindings.bindings {
                // <Q11 hint="see DisjunctionStep" />
                let state = cts.storeStepState()
                defer {
                    cts.loadStepState(state)
                }
                if attempt(binding: binding) {
                    isAnySolved = true
                }
            }
            
            return isAnySolved
        }
        
        /// Attempts to apply a given binding to the constraint system.
        /// - Parameters:
        ///   - binding:
        /// - Returns: A boolean value indicating whether the constraint system successfully simplified constraints.
        private func attempt(binding: PotentialBinding) -> Bool {
            pr.goToLineHead()
            pr.println("attempt: \(binding)")
            
            cts.addConstraint(kind: .bind,
                              left: bindings.typeVariable,
                              right: binding.type)

            guard cts.simplify() else {
                return false
            }
            
            return ComponentStep(work: work).run()
        }
    }
    
    public struct DisjunctionStep {
        public let work: SolveWork
        private let cts: ConstraintSystem
        private let pr: Printer
        public let disjunction: ConstraintEntry
        public init(work: SolveWork,
                    disjunction: ConstraintEntry)
        {
            self.work = work
            self.cts = work.cts
            self.pr = work.cts.printer
            self.disjunction = disjunction
        }
        
        public func run() -> Bool {
            let choices: [Constraint]
            switch disjunction.constraint {
            case .disjunction(let dj): choices = dj.constraints
            default: preconditionFailure()
            }
            
            pr.goToLineHead()
            pr.println("(disjunctionStep")
            pr.push()
            cts._removeConstraintEntry(disjunction)
            defer {
                cts._addConstraintEntry(disjunction)
                pr.pop()
                pr.print(")")
            }
            
            var isAnySolved = false
            
            for choice in choices {
                let state = cts.storeStepState()
                defer {
                    cts.loadStepState(state)
                }
                if attempt(choice: choice) {
                    isAnySolved = true
                }
            }
            
            return isAnySolved
        }
        
        /// Attempts to apply a given constraint to the constraint system.
        /// - Parameters:
        ///   - choice:
        /// - Returns: A boolean value indicating whether the constraint system successfully simplified constraints.
        private func attempt(choice: Constraint) -> Bool {
            pr.goToLineHead()
            pr.println("attempt: \(choice)")
            switch cts.simplify(constraint: choice) {
            case .solved:
                break
            case .ambiguous:
                cts._addConstraintEntry(ConstraintEntry(choice))
            case .failure:
                cts.fail(constraint: ConstraintEntry(choice))
            }
            
            guard cts.simplify() else {
                return false
            }
            
            return ComponentStep(work: work).run()
        }
    }

}
