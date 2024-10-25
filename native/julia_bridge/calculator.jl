module Calculator

export add_numbers, multiply_array

"""
Simple addition function
"""
function add_numbers(a::Float64, b::Float64)
    return a + b
end

"""
Multiply all elements in an array
"""
function multiply_array(arr::Vector{Float64})
    return prod(arr)
end

end
