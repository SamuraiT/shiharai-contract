// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from 'hardhat'
import 'dotenv/config'

const main = async () => {
  const Usdc = await ethers.getContractFactory('MockERC20')
  const usdc = await Usdc.attach('')

  console.log('usdc', usdc.address)
  const accounts = JSON.parse(process.env.ACCOUNTS || '')
  const amount = ethers.utils.parseUnits('5000000', 18)
  for (const account of accounts) {
    usdc.mint(account, amount)
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
