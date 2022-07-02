// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from 'hardhat'

const main = async () => {
  const Usdc = await ethers.getContractFactory('MockERC20')
  const usdc = await Usdc.deploy('test-usdc')
  await usdc.deployed()

  console.log('usdc', usdc.address)
  const Shihari = await ethers.getContractFactory('Shiharai')
  const shihari = await Shihari.deploy(usdc.address)
  await shihari.deployed()
  console.log('shihari deployed to:', shihari.address)
  const accounts = JSON.parse(process.env.ACCOUNTS || '')
  const amount = ethers.utils.parseUnits('5000000', 18)
  for (const account of accounts) {
    await usdc.mint(account, amount)
    console.log('minted to:', account)
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
