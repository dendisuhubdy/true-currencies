import { expect, use } from 'chai'
import { Wallet } from 'ethers'
import { MockProvider, solidity } from 'ethereum-waffle'
import { beforeEachWithFixture } from '../utils/beforeEachWithFixture'
import { deployWithExisting } from '../../scripts/deploy_mainnet'
import { deployBehindProxy, setupDeployer } from '../../scripts/utils'

use(solidity)
describe.skip('Deploying', () => {
  let deployer: Wallet
  let provider: MockProvider

  beforeEachWithFixture(async (_provider, wallets) => {
    ([deployer] = wallets)
    provider = _provider

    const deploy = setupDeployer(deployer)
    const [registryImplementation, registryProxy, registry] = await deployBehindProxy(deployer, 'ProvisionalRegistryImplementation')
    const [trueUSDImplementation, trueUSDProxy, trueUSD] = await deployBehindProxy(deployer, 'TrueUSD')
    const [, , tokenController] = await deployBehindProxy(deployer, 'TokenController')
    await registryProxy.upgradeTo(registryImplementation.address)
    await trueUSDProxy.upgradeTo(trueUSDImplementation.address)
    await trueUSD.initialize()
    await registry.initialize()

    const lendingPoolCoreMock = await deploy('LendingPoolCoreMock')
    const aTokenMock = await deploy('ATokenMock', trueUSDProxy.address, lendingPoolCoreMock.address)
    const lendingPoolMock = await deploy('LendingPoolMock', lendingPoolCoreMock.address, aTokenMock.address)

    // uniswapFactory
    const uniswapFactory = await deploy('uniswap_factory')
    const uniswapTemplate = await deploy('uniswap_exchange')
    await uniswapFactory.initializeFactory(uniswapTemplate.address)
    const owner = Wallet.createRandom()

    await deployWithExisting(deployer.privateKey, {
      registry: registry.address,
      trueUsd: trueUSD.address,
      aaveLendingPool: lendingPoolMock.address,
      aTUSD: aTokenMock.address,
      uniswapFactory: uniswapFactory.address,
      tokenController: tokenController.address,
    }, owner.address, provider)
  })

  it('deploys contracts', async () => {
    expect(await provider.getCode('0xbF42E6bD8fA05956E28F7DBE274657c262526F3D')).to.not.equal('0x')
  }).timeout(10_000)
})
