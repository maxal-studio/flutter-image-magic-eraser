# Create environment

# python3 -m venv magic_env

# source magic_env/bin/activate

# pip3 install onnx

# python3 get_inputs.py

import onnx

model = onnx.load("./models/lama_fp32.onnx")

print("Model Inputs:")
for input_tensor in model.graph.input:
    print(f"- Name: {input_tensor.name}")
    print(f"- Shape: {input_tensor.type.tensor_type.shape.dim}")
    print(f"- Type: {input_tensor.type.tensor_type.elem_type}")
