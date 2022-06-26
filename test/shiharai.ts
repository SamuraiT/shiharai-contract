import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { Contract } from 'ethers'
import { ethers } from 'hardhat'

describe('Shiharai', function () {
  let shirahaiContract: Contract,
    owner: SignerWithAddress,
    alice: SignerWithAddress,
    bob: SignerWithAddress,
    erc20: Contract

  beforeEach(async () => {
    ;[owner, alice, bob] = await ethers.getSigners()
    const MockERC20 = await ethers.getContractFactory('MockERC20')
    erc20 = await MockERC20.deploy('usdc')
    await erc20.deployed()

    const ShirahaiContract = await ethers.getContractFactory('Shiharai')
    shirahaiContract = await ShirahaiContract.deploy(erc20.address)
    await shirahaiContract.deployed()
  })

  describe('setSupportedToken', () => {
    it('setSupportedToken successfully', async () => {
      await shirahaiContract.setSupportedToken(ethers.constants.AddressZero)
      expect(await shirahaiContract.supportedTokensMap(erc20.address)).to.be.eq(
        erc20.address
      )
      expect(
        await shirahaiContract.supportedTokensMap(ethers.constants.AddressZero)
      ).to.be.eq(ethers.constants.AddressZero)
    })
  })
})
