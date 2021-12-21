const hre = require("hardhat");
const ethers = hre.ethers;

async function deploy(name, args) {
  const Contract = await ethers.getContractFactory(name);
  console.log(name + "contract size: ", Contract.bytecode.length / 2);
  const contract = await Contract.deploy(...args, { gasLimit: 5000000 });
  await contract.deployed();
  console.log(name + " deployed to:", contract.address);
  return contract;
}

async function main() {
  await hre.run("compile");
  const vault = await deploy("Vault", []);
  await vault.initializeLock();
  await deploy("Factory", [vault.address]);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
