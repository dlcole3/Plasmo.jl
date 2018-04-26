
import MathProgBase.SolverInterface:AbstractMathProgSolver

#A constraint between JuMP Models (nodes)
#Should link constraints be strictly equality?  Could always just convert inequality with slacks
#####################################################
# Link Constraint
#####################################################
mutable struct LinkConstraint <: JuMP.AbstractConstraint
    terms::JuMP.AffExpr
    lb::Number
    ub::Number
end
#Constructor
LinkConstraint(con::JuMP.LinearConstraint) = LinkConstraint(con.terms,con.lb,con.ub)
#Get the Link constraint from a reference
LinkConstraint(ref::ConstraintRef) = ref.m.linkdata.linkconstraints[ref.idx]

#Get number of nodes in a link constraint
function PlasmoGraphBase.getnodes(con::LinkConstraint)
    vars = con.terms.vars
    nodes = unique([getnode(var) for var in vars])
    return nodes
end

#Get number of nodes in a link constraint
#Could just look up the index
function getnumnodes(con::LinkConstraint)
    nodes = getnodes(con)
    return length(nodes)
end

#####################################################
# Link Data
#####################################################
mutable struct LinkData
    linkconstraints::Vector{LinkConstraint}          #all links
    simple_links::Vector{Int}  #references to the 2 node link constraints
    hyper_links::Vector{Int}   #references to linkconstraints with 3 or more nodes
end
LinkData() = LinkData(Vector{LinkConstraint}(),Vector{Int}(),Vector{Int}())

#####################################################
# Link Model
#####################################################
#A link model is a simple struct that stores link data.
mutable struct LinkModel <: JuMP.AbstractModel   #subtyping here so I can get ConstraintRef
    linkdata::LinkData  #LinkModel's store indices for each link constraint added
    objval::Number
    objective::JuMP.AffExpr  #Possibly a function of multiple model variables.  Strictly linear
    solver::AbstractMathProgSolver
end
LinkModel() = LinkModel(LinkData(),0,JuMP.AffExpr(),JuMP.UnsetSolver())
getlinkdata(model::LinkModel) = model.linkdata

#Get the 2 variable or multi-variable linkconstraints
getlinkconstraints(model::LinkModel) = getlinkdata(model).linkconstraints
getsimplelinkconstraints(model::LinkModel) = getlinkdata(model).linkconstraints[getlinkdata(model).simple_links]
gethyperlinkconstraints(model::LinkModel) = getlinkdata(model).linkconstraints[getlinkdata(model).hyper_links]

is_linkconstr(con::LinkConstraint) = getnumnodes(con) == 2? true : false
is_hyperconstr(con::LinkConstraint) = getnumnodes(con) > 2? true : false

#Extend JuMP's add constraint for link models.  Return a reference to the constraint
function JuMP.addconstraint(model::LinkModel,constr::JuMP.LinearConstraint)
    #TODO Do some error checking here
    linkdata = getlinkdata(model)
    linkconstr = LinkConstraint(constr)
    push!(linkdata.linkconstraints,linkconstr)
    ref = ConstraintRef{LinkModel,LinkConstraint}(model, length(linkdata.linkconstraints))

    if is_linkconstr(linkconstr )
        push!(linkdata.simple_links,length(linkdata.linkconstraints))
    elseif is_hyperconstr(linkconstr )
        push!(linkdata.hyper_links,length(linkdata.linkconstraints))
    else
        error("constraint doesn't make sense")
    end
    return ref
end
