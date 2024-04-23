import React, { useState } from "react";
import "./MintForm.css"; // Import the CSS file

const MintForm = ({ onMint }) => {
  const [tokenName, setTokenName] = useState("");
  const [tokenTransferFee, setTokenTransferFee] = useState(0);
  const [itemPrice, setItemPrice] = useState(0);
  const [tokenSymbolName, setTokenSymbolName] = useState("");
  const [tokenName2, setTokenName2] = useState("");
  const [totalTokenSupply, setTotalTokenSupply] = useState(0);
  const [selectedImage, setSelectedImage] = useState(null);

  const handleFileChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onloadend = () => {
        setTokenName(reader.result); // Store the entire base64 string
        setSelectedImage(reader.result); // Store the entire base64 string for display
      };
      reader.readAsDataURL(file);
    }
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    console.log("token name", tokenName);
    onMint({
      tokenName,
      tokenTransferFee,
      itemPrice,
      tokenSymbolName,
      tokenName2,
      totalTokenSupply,
    });
  };

  console.log("image",selectedImage)
  return (
    <>
      <form onSubmit={handleSubmit} className="mint-form">
        <label>
          {/* Image element to display selected image */}
          {selectedImage && (
            <img
              src={selectedImage}
              alt="Selected Image"
              className="selected-image"
              style={{ width: '50px', height: '50px' }} // Resizing to 20px by 20px
            />
          )}
          Token Name:
          {/* Check if the file input is visible and accessible */}
          <input
            type="file"
            onChange={handleFileChange}
            className="form-input"
          />
        </label>

        <label>
          Token Transfer Fee:
          <input
            type="number"
            value={tokenTransferFee}
            onChange={(e) => setTokenTransferFee(Number(e.target.value))}
            className="form-input"
          />
        </label>
        <label>
          Item Price:
          <input
            type="number"
            value={itemPrice}
            onChange={(e) => setItemPrice(Number(e.target.value))}
            className="form-input"
          />
        </label>
        <label>
          Token Symbol Name:
          <input
            type="text"
            value={tokenSymbolName}
            onChange={(e) => setTokenSymbolName(e.target.value)}
            className="form-input"
          />
        </label>
        <label>
          Second Token Name:
          <input
            type="text"
            value={tokenName2}
            onChange={(e) => setTokenName2(e.target.value)}
            className="form-input"
          />
        </label>
        <label>
          Total Token Supply (only Trillions each unit 1T):
          <input
            type="number"
            value={totalTokenSupply}
            onChange={(e) => setTotalTokenSupply(Number(e.target.value))}
            className="form-input"
          />
        </label>
        <button type="submit" className="submit-button">
          deploy
        </button>
      </form>
    </>
  );
};

export default MintForm;
