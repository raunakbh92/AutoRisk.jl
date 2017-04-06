export
    TDPredictor,
    predict,
    update!,
    reset!

"""
Description:
    - predictor that uses TD-learning for learning.
"""
type TDPredictor <: PredictionModel
    grid::RectangleGrid # for intepolating continuous states
    values::Array{Float64} # for maintaining state values (target dim, num unique states)
    targets::Array{Float64} # temp container for returning target values
    target_dim::Int # dimension of output
    lr::Float64 # learning rate for td update
    discount::Float64 # discount rate (not entirely sound here)
    function TDPredictor(grid::RectangleGrid, target_dim::Int;
            lr::Float64 = .1, discount::Float64 = 1.)
        values = zeros(Float64, target_dim, length(grid))
        targets = zeros(Float64, target_dim)
        return new(grid, values, targets, target_dim, lr, discount)
    end
end

"""
Description:
    - predict the value of a state by intepolating it 

Args:
    - predictor: the TDPredictor
    - state: the state vector shape = (state_dim)

Returns:
    - the target values associated with the state
"""
function predict(predictor::TDPredictor, state::Vector{Float64})
    for tidx in 1:predictor.target_dim
        inds, ws = interpolants(predictor.grid, state)
        predictor.targets[tidx] = dot(predictor.values[tidx, inds], ws)
    end
    return predictor.targets
end

function predict(predictor::TDPredictor, states::Array{Float64})
    state_dim, num_states = size(states)
    values = zeros(predictor.target_dim, num_states)
    for sidx in 1:num_states
        values[:, sidx] = predict(predictor, states[:, sidx])
    end
    return values
end


"""
Description:
    - updates the predictors table via incremental update

Args:
    - predictor: the TDPredictor
    - states: the states array shape = (state_dim, num_states)
    - values: the (estimated) values of those states = (target_dim, num_states)
"""
function update!(predictor::TDPredictor, states::Array{Float64}, 
        values::Array{Float64})
    state_dim, num_states = size(states)
    target_dim, num_targets = size(values)
    assert(num_states == num_targets)
    # for each state, interpolate it, compute it's td error, perform an update
    total_td_error = 0
    for sidx in 1:num_states
        inds, ws = interpolants(predictor.grid, states[:, sidx])
        for tidx in 1:predictor.target_dim
            for (ind, w) in zip(inds, ws)
                # this is discounting the reward and the value, which only makes 
                # sense if the reward is received in transitioning to s'
                td_error = w * (predictor.discount * values[tidx, sidx] 
                    - predictor.values[tidx, ind])
                predictor.values[tidx, ind] += predictor.lr * td_error
                total_td_error += td_error
            end
        end
    end
    return total_td_error
end

reset!(predictor::TDPredictor) = fill!(predictor.values, 0)