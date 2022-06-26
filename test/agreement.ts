/* eslint-disable camelcase */
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { Contract, utils, BigNumber } from 'ethers'
import { ethers } from 'hardhat'
import {
  MockERC20__factory,
  Shiharai__factory,
} from '../typechain'

describe('Shiharai', function () {
  let shirahaiContract: Contract,
    shirahaiContractMock: Contract,
    owner: SignerWithAddress,
    alice: SignerWithAddress,
    bob: SignerWithAddress,
    erc20: Contract

  beforeEach(async () => {
    ;[owner, alice, bob] = await ethers.getSigners()
    const MockERC20 = new MockERC20__factory(owner)
    erc20 = await MockERC20.deploy('usdc')
    await erc20.deployed()
    const amount = utils.parseUnits('1000', 18)
    erc20.mint(alice.address, amount)
    erc20.mint(bob.address, amount)
    // const ShirahaiContract = await ethers.getContractFactory('Shiharai')
    const ShiharaiContract = new Shiharai__factory(owner)
    shirahaiContract = await ShiharaiContract.deploy(erc20.address)
    await shirahaiContract.deployed()
  })

  describe('issueAgreement', () => {
    let issueAgreement: any, nextMonth: number

    this.beforeEach(async () => {
      const now = new Date()
      nextMonth =
        new Date(
          now.getFullYear(),
          now.getMonth() + 1,
          now.getDay()
        ).getTime() / 1000

      issueAgreement = {
        name: utils.keccak256(utils.toUtf8Bytes('hoge')),
        with: alice.address,
        token: erc20.address,
        amount: utils.parseUnits('100', 18),
        term: 1, // 1month
        paysAt: nextMonth
      }
    })

    it('issue agreement successfully', async () => {
      const amount = utils.parseUnits('10000', 18)
      await erc20.approve(shirahaiContract.address, amount)
      await shirahaiContract.deposit(erc20.address, amount)

      await expect(
        shirahaiContract.issueAgreement(...Object.values(issueAgreement))
      ).to.emit(shirahaiContract, 'IssuedAgreement')

      const agreement = await shirahaiContract.agreements(1)
      expect(agreement.issuer).to.be.eq(owner.address)
      expect(agreement.undertaker).to.be.eq(alice.address)
      expect(agreement.payment).to.be.eq(erc20.address)
      expect(agreement.amount).to.be.eq(utils.parseUnits('100', 18))
      expect(agreement.paysAt).to.be.eq(nextMonth)
    })
  })

  describe('deposit', () => {
    it('deposit successfully', async () => {
      const balance = await erc20.balanceOf(owner.address)
      const amount = utils.parseUnits('10000', 18)
      await erc20.approve(shirahaiContract.address, amount)
      await expect(shirahaiContract.deposit(erc20.address, amount))
        .to.emit(shirahaiContract, 'Deposit')
        .withArgs(owner.address, erc20.address, amount)
      expect(await erc20.balanceOf(owner.address)).to.eq(balance.sub(amount))
      expect(await erc20.balanceOf(shirahaiContract.address)).to.eq(amount)
      expect(
        await shirahaiContract.depositedAmountMap(owner.address, erc20.address)
      ).to.eq(amount)
    })

    it('deposit successfully with alice', async () => {
      const balance = await erc20.balanceOf(alice.address)
      const amount = utils.parseUnits('1000', 18)
      await erc20.connect(alice).approve(shirahaiContract.address, amount)
      await expect(
        shirahaiContract.connect(alice).deposit(erc20.address, amount)
      )
        .to.emit(shirahaiContract, 'Deposit')
        .withArgs(alice.address, erc20.address, amount)
      expect(await erc20.balanceOf(alice.address)).to.eq(balance.sub(amount))
      expect(await erc20.balanceOf(shirahaiContract.address)).to.eq(amount)
      expect(
        await shirahaiContract.depositedAmountMap(alice.address, erc20.address)
      ).to.eq(amount)
    })

    it('revert deposit', async () => {
      const balance = await erc20.balanceOf(alice.address)
      const amount = utils.parseUnits('1000000', 18)
      await erc20.connect(alice).approve(shirahaiContract.address, amount)
      await expect(
        shirahaiContract.connect(alice).deposit(erc20.address, amount)
      ).to.be.reverted
      expect(await erc20.balanceOf(alice.address)).to.eq(balance)
      expect(await erc20.balanceOf(shirahaiContract.address)).to.eq(0)
      expect(
        await shirahaiContract.depositedAmountMap(alice.address, erc20.address)
      ).to.eq(0)
    })
  })

  describe('depositAndissueAgreement', () => {
    it('successfully issue and desposit', async () => {
      const now = new Date()
      const nextMonth =
        new Date(
          now.getFullYear(),
          now.getMonth() + 1,
          now.getDay()
        ).getTime() / 1000

      const amount = utils.parseUnits('100', 18)
      const issueAgreement = {
        name: utils.keccak256(utils.toUtf8Bytes('hoge')),
        with: alice.address,
        token: erc20.address,
        amount: amount,
        term: 1, // 1month
        paysAt: nextMonth
      }

      const balance = await erc20.balanceOf(owner.address)
      await erc20.approve(shirahaiContract.address, amount)
      await expect(
        shirahaiContract.depositAndissueAgreement(
          ...Object.values(issueAgreement)
        )
      )
        .to.emit(shirahaiContract, 'IssuedAgreement')
        .to.emit(shirahaiContract, 'Deposit')
        .withArgs(owner.address, erc20.address, amount)

      expect(await erc20.balanceOf(owner.address)).to.eq(balance.sub(amount))
      expect(await erc20.balanceOf(shirahaiContract.address)).to.eq(amount)
      expect(
        await shirahaiContract.depositedAmountMap(owner.address, erc20.address)
      ).to.eq(amount)
      const agreement = await shirahaiContract.agreements(1)
      expect(agreement.issuer).to.be.eq(owner.address)
      expect(agreement.undertaker).to.be.eq(alice.address)
      expect(agreement.payment).to.be.eq(erc20.address)
      expect(agreement.amount).to.be.eq(amount)
    })
  })


  describe('getAgreements', () => {
    let now: Date, nextMonth: number, amount: BigNumber, balance: BigNumber

    beforeEach(async () => {
      now = new Date()
      nextMonth =
        new Date(
          now.getFullYear(),
          now.getMonth() + 1,
          now.getDay()
        ).getTime() / 1000

      amount = utils.parseUnits('1000', 18)
      const issueAgreementWithAlice = {
        name: utils.keccak256(utils.toUtf8Bytes('hoge')),
        with: alice.address,
        token: erc20.address,
        amount: amount,
        term: 1, // 1month
        paysAt: nextMonth
      }
      const issueAgreementWithBob = {
        name: utils.keccak256(utils.toUtf8Bytes('hoge')),
        with: bob.address,
        token: erc20.address,
        amount: amount,
        term: 1, // 1month
        paysAt: nextMonth
      }
      balance = await erc20.balanceOf(owner.address)
      await erc20.approve(shirahaiContract.address, balance)
      await shirahaiContract.depositAndissueAgreement(
        ...Object.values(issueAgreementWithAlice)
      )

      await shirahaiContract.depositAndissueAgreement(
        ...Object.values(issueAgreementWithBob)
      )
    })

    it('getIssuersAgreements', async () => {
      const agreements = await shirahaiContract.getIssuersAgreements(
        owner.address
      )

      expect(agreements[0].issuer).to.be.eq(owner.address)
      expect(agreements[0].undertaker).to.be.eq(alice.address)
      expect(agreements[0].payment).to.be.eq(erc20.address)
      expect(agreements[0].amount).to.be.eq(amount)

      expect(agreements[1].issuer).to.be.eq(owner.address)
      expect(agreements[1].undertaker).to.be.eq(bob.address)
      expect(agreements[1].payment).to.be.eq(erc20.address)
      expect(agreements[1].amount).to.be.eq(amount)
    })
  })
})
