// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from 'hardhat'

const main = async () => {
  const Usdc = await ethers.getContractFactory('MockERC20')
  const usdc = await Usdc.attach('0x6FDCcffcb7e61EB05fa63d8830633E8105B90025')

  console.log('usdc', usdc.address)
  const Shihari = await ethers.getContractFactory('Shiharai')
  const shihari = await Shihari.deploy(usdc.address)
  await shihari.deployed()

  console.log('shihari deployed to:', shihari.address)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
